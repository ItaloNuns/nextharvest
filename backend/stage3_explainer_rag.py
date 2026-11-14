import json
import os
import httpx
from pydantic import BaseModel

GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

# shortcut: in-memory token-overlap RAG over curated USDA NRCS/FAO/NASA snippets, upgrade to PostGIS/pgvector when indexing full PDFs
KNOWLEDGE_BASE = [
    {
        "id": "nrcs_legume_n",
        "tags": {"alfalfa", "soybeans", "chickpea", "rye_vetch_cover", "fabaceae", "nitrogen"},
        "text": "USDA NRCS Soil Health: Leguminosas (Fabaceae) fixam nitrogênio atmosférico via simbiose com Rhizobium, reduzindo a necessidade de fertilizante sintético na cultura subsequente (gramínea/Poaceae).",
    },
    {
        "id": "nrcs_bare_soil",
        "tags": {"winter_wheat", "rye_vetch_cover", "oats", "canola", "bare", "erosion"},
        "text": "USDA NRCS Cover Crops: Manter raízes vivas e cobertura de inverno elimina janelas de solo exposto (NDVI < 0.22), reduzindo o impacto cinético da chuva (GPM IMERG) e a erosão laminar.",
    },
    {
        "id": "fao_drought_kc",
        "tags": {"sorghum", "chickpea", "sunflower", "water", "drought"},
        "text": "FAO GAEZ v4: Sorgo, grão-de-bico e girassol possuem menor coeficiente de cultura (Kc 0.60-0.70) e sistema radicular profundo, mantendo produtividade sob déficit hídrico (OpenET/ECOSTRESS).",
    },
    {
        "id": "nrcs_pest_break",
        "tags": {"pest", "rotation", "family", "poaceae", "fabaceae", "brassicaceae", "asteraceae"},
        "text": "USDA Ag Data Commons: Alternar famílias botânicas distintas interrompe o ciclo de patógenos de solo, nematoides e pragas específicas (como gorgulho-da-alfafa e lagarta-da-raiz do milho).",
    },
    {
        "id": "nasa_sat_vs_ground",
        "tags": {"smap", "uncertainty", "satellite", "ground", "lab"},
        "text": "NASA Earthdata: SMAP (9 km) e NASA POWER (50 km) medem tendências regionais de umidade e clima, mas não substituem análise química de solo local (NPK, pH, salinidade) e inspeção de campo.",
    },
]

GLOSSARY = {
    "ndvi": "Índice de Vegetação por Diferença Normalizada (-1 a 1): mede o vigor verde da planta via luz vermelha e infravermelha (Landsat/Sentinel-2/MODIS). Valores < 0,22 indicam solo exposto ou palhada seca.",
    "evapotranspiracao": "Soma da água que evapora do solo com a água transpirada pelas folhas (medida pelo ECOSTRESS e OpenET em mm). Indica a sede real da lavoura.",
    "smap_anomaly": "Desvio padronizado (Z-score) da umidade do solo medida por satélite (SMAP/NASA POWER) em relação à média histórica do mesmo mês. Valores abaixo de -1,0 indicam seca anormal na raiz.",
    "satelite_vs_solo": "Satélites da NASA enxergam padrões térmicos, hídricos e ópticos de grandes áreas ao longo de décadas, enquanto amostras de solo e sensores locais medem nutrientes (NPK), compactação e pragas no pé da planta.",
}


class StrategyExplanation(BaseModel):
    why_suggested: str
    supporting_evidence: list[str]
    expected_benefits: list[str]
    information_gaps_and_uncertainty: list[str]
    risks_requiring_local_review: list[str]


class Stage3Response(BaseModel):
    explanations: dict[str, StrategyExplanation]


def retrieve_agronomic_snippets(codes: list[str], extra_tags: list[str] | None = None) -> list[str]:
    query_tags = set(codes) | set(extra_tags or []) | {"smap", "uncertainty", "pest"}
    scored = sorted(
        KNOWLEDGE_BASE,
        key=lambda doc: len(doc["tags"] & query_tags),
        reverse=True,
    )
    return [doc["text"] for doc in scored[:3]]


def _build_deterministic_explanation(strat: dict, stage1: dict, uncertainty: dict) -> StrategyExplanation:
    codes = strat["codes"]
    m = strat["metrics_radar"]
    bare = stage1.get("bare_soil_months", [])
    min_cwd = min(stage1.get("crop_water_deficit_mm", {1: 0.0}).values(), default=0.0)
    min_z = min(stage1.get("soil_moisture_anomaly_z", {1: 0.0}).values(), default=0.0)
    hot_slope = stage1.get("climate_trends_per_year", {}).get("hot_days_above_35c_slope", 0.0)
    snippets = retrieve_agronomic_snippets(codes, ["bare"] if bare else ["water"])

    why = (
        "Representa o manejo atual do talhão como linha de base comparativa."
        if strat["is_baseline"]
        else f"Selecionada via TOPSIS (score {strat['topsis_score']}/100) para otimizar eficiência hídrica ({m['water_efficiency_score']}/100), saúde do solo ({m['soil_health_organic_matter_score']}/100) e quebra de pragas ({m['pest_cycle_disruption_score']}/100)."
    )
    evidence = [
        f"NASA POWER / SMAP indicam anomalia mínima de umidade radicular Z={min_z} e balanço hídrico crítico de {min_cwd} mm/mês.",
        f"Série histórica detectou {len(bare)} mês(es) de solo exposto ({bare}) e tendência de {hot_slope:+.2f} dias/ano acima de 35°C.",
        snippets[0],
    ]
    benefits = [
        f"Score de proteção contra erosão de {m['erosion_protection_score']}/100 e aporte de nitrogênio de {m['nitrogen_fixation_score']}/100.",
        snippets[1],
    ]
    gaps = uncertainty.get("reasons") or ["Dados de satélite precisam ser cruzados com análise química de solo local."]
    risks = [
        "Validar com engenheiro agrônomo local a janela exata de plantio, cultivares adaptadas e disponibilidade de maquinário/mercado regional.",
        "Não substitui o julgamento do produtor rural nem laudo laboratorial de fertilidade e nematoides.",
    ]
    return StrategyExplanation(
        why_suggested=why,
        supporting_evidence=evidence,
        expected_benefits=benefits,
        information_gaps_and_uncertainty=gaps,
        risks_requiring_local_review=risks,
    )


def generate_stage3_explanations(
    stage1: dict,
    stage2: dict,
    api_key: str | None = None,
) -> dict:
    """Attach the 5 mandatory NASA Space Apps explainability fields to each rotation strategy."""
    key = api_key or os.getenv("GEMINI_API_KEY")
    strategies = stage2["strategies"]
    uncertainty = stage2["uncertainty"]

    explanations_by_id = {
        s["strategy_id"]: _build_deterministic_explanation(s, stage1, uncertainty)
        for s in strategies
    }

    if key:
        prompt = {
            "role": "Gere explicações agronômicas em português para o produtor rural baseadas nos dados da NASA e USDA.",
            "stage1_indicators": stage1,
            "stage2_strategies": strategies,
            "uncertainty": uncertainty,
            "rag_context": [doc["text"] for doc in KNOWLEDGE_BASE],
        }
        payload = {
            "contents": [{"parts": [{"text": json.dumps(prompt, ensure_ascii=False)}]}],
            "generationConfig": {
                "responseMimeType": "application/json",
                "responseSchema": Stage3Response.model_json_schema(),
            },
        }
        r = httpx.post(f"{GEMINI_URL}?key={key}", json=payload, timeout=30)
        r.raise_for_status()
        parsed = Stage3Response.model_validate_json(
            r.json()["candidates"][0]["content"]["parts"][0]["text"]
        )
        explanations_by_id.update(parsed.explanations)

    return {
        "strategies": [
            {
                **s,
                "explanation": explanations_by_id[s["strategy_id"]].model_dump(),
            }
            for s in strategies
        ],
        "uncertainty": uncertainty,
        "disclaimer": "Esta ferramenta apoia a tomada de decisão com observações da Terra da NASA, mas não substitui o julgamento do produtor rural ou de um engenheiro agrônomo local.",
    }


def explain_scientific_term(term: str) -> str:
    return GLOSSARY.get(
        term.lower().strip(),
        "Indicador agroambiental monitorado via sensoriamento remoto (NASA) que deve ser validado com medições locais no talhão.",
    )
