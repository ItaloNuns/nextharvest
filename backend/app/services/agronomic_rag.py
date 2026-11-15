"""In-memory tag-overlap RAG over curated USDA NRCS / FAO / NASA snippets."""

from __future__ import annotations

from app.schemas.rotation_models import HarmonizedSummary
from app.services.crop_catalog import CROPS, fold_name, resolve_crop

KNOWLEDGE_BASE: list[dict[str, object]] = [
    {
        "id": "nrcs_legume_n",
        "tags": {"alfalfa", "soybeans", "chickpea", "rye_vetch_cover", "fabaceae", "nitrogen"},
        "text": (
            "USDA NRCS Soil Health: Leguminosas (Fabaceae) fixam nitrogênio atmosférico via "
            "simbiose com Rhizobium, reduzindo a necessidade de fertilizante sintético na "
            "cultura subsequente (gramínea/Poaceae)."
        ),
    },
    {
        "id": "nrcs_bare_soil",
        "tags": {"winter_wheat", "rye_vetch_cover", "oats", "canola", "bare", "erosion"},
        "text": (
            "USDA NRCS Cover Crops: Manter raízes vivas e cobertura de inverno elimina janelas "
            "de solo exposto (NDVI < 0.22), reduzindo o impacto cinético da chuva (GPM IMERG) "
            "e a erosão laminar."
        ),
    },
    {
        "id": "fao_drought_kc",
        "tags": {"sorghum", "chickpea", "sunflower", "water", "drought"},
        "text": (
            "FAO GAEZ v4: Sorgo, grão-de-bico e girassol possuem menor coeficiente de cultura "
            "(Kc 0.60-0.70) e sistema radicular profundo, mantendo produtividade sob déficit "
            "hídrico (OpenET/ECOSTRESS)."
        ),
    },
    {
        "id": "nrcs_pest_break",
        "tags": {
            "pest",
            "rotation",
            "family",
            "poaceae",
            "fabaceae",
            "brassicaceae",
            "asteraceae",
        },
        "text": (
            "USDA Ag Data Commons: Alternar famílias botânicas distintas interrompe o ciclo de "
            "patógenos de solo, nematoides e pragas específicas (como gorgulho-da-alfafa e "
            "lagarta-da-raiz do milho)."
        ),
    },
    {
        "id": "nasa_sat_vs_ground",
        "tags": {"smap", "uncertainty", "satellite", "ground", "lab"},
        "text": (
            "NASA Earthdata: SMAP (9 km) e NASA POWER (50 km) medem tendências regionais de "
            "umidade e clima, mas não substituem análise química de solo local (NPK, pH, "
            "salinidade) e inspeção de campo."
        ),
    },
]


def retrieve_agronomic_snippets(
    codes: list[str],
    extra_tags: list[str] | None = None,
) -> list[str]:
    query_tags = set(codes) | set(extra_tags or []) | {"smap", "uncertainty", "pest"}
    scored = sorted(
        KNOWLEDGE_BASE,
        key=lambda doc: len(set(doc["tags"]) & query_tags),  # type: ignore[arg-type]
        reverse=True,
    )
    return [str(doc["text"]) for doc in scored[:3]]


def codes_from_labels(labels: list[str]) -> list[str]:
    codes: list[str] = []
    for label in labels:
        direct = resolve_crop(label)
        if direct:
            codes.append(direct)
            continue
        folded = fold_name(label)
        best: str | None = None
        best_len = 0
        for code, spec in CROPS.items():
            for candidate in (code, str(spec["name"])):
                token = fold_name(candidate)
                if token and token in folded and len(token) > best_len:
                    best = code
                    best_len = len(token)
        if best:
            codes.append(best)
    return codes


def extra_tags_from_summary(summary: HarmonizedSummary) -> list[str]:
    tags = ["water"]
    if summary.bare_field_months:
        tags.append("bare")
    if summary.water_balance_deficit_mm < 0:
        tags.append("drought")
    if summary.rootzone_source != "power_gwetroot" and summary.smap_rootzone_anomaly_z != 0:
        tags.append("smap")
    return tags
