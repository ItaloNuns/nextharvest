from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator

HealthStatus = Literal["ok", "warning", "critical"]
EtSource = Literal["openet", "power", "none"]


class HealthResponse(BaseModel):
    status: str
    database: str
    redis: str


class Location(BaseModel):
    lat: float
    lon: float
    state: str
    county: str


class SoilProfile(BaseModel):
    mapunit_name: str
    organic_matter_pct: float
    available_water_capacity_cm_cm: float
    drainage_class: str
    hydrologic_group: str
    erosion_k_factor: float


class HarmonizedSummary(BaseModel):
    annual_precip_mm: float
    annual_et_demand_mm: float
    water_balance_deficit_mm: float
    smap_rootzone_anomaly_z: float
    bare_field_months: list[str]
    soil_profile: SoilProfile
    rootzone_source: Literal["none", "power_gwetroot"] = "none"


class DiagnosticDimension(BaseModel):
    id: Literal["water", "soil", "sources"]
    status: HealthStatus
    label: str


class DiagnosticHealth(BaseModel):
    overall: HealthStatus
    data_quality: HealthStatus
    dimensions: list[DiagnosticDimension]


class AnalysisMeta(BaseModel):
    climate_ok: bool
    soil_ok: bool
    et_source: EtSource
    failures: list[str] = []


class MetricsRadar(BaseModel):
    water_efficiency_score: int = Field(ge=0, le=100)
    soil_health_organic_matter_score: int = Field(ge=0, le=100)
    nitrogen_fixation_score: int = Field(ge=0, le=100)
    erosion_protection_score: int = Field(ge=0, le=100)
    pest_cycle_disruption_score: int = Field(ge=0, le=100)
    market_viability_score: int = Field(ge=0, le=100)


class RotationExplanation(BaseModel):
    why_suggested: str
    supporting_evidence: list[str]
    expected_benefits: list[str]
    information_gaps_and_uncertainty: list[str]
    risks_requiring_local_review: list[str]


class RotationStrategy(BaseModel):
    strategy_id: str
    name: str
    is_baseline: bool
    sequence: list[str]
    metrics_radar: MetricsRadar
    explanation: RotationExplanation


class RotationRecommendation(BaseModel):
    field_id: str
    placeholder: bool = True
    message: str
    location: Location
    harmonized_summary: HarmonizedSummary
    strategies: list[RotationStrategy]
    nass_used: bool = False


DEMO_PRIORITIES_JSON: dict[str, object] = {
    "water_savings": 5,
    "soil_organic_matter": 3,
    "erosion_control": 4,
    "pest_cycle_break": 3,
    "forage_value": 2,
    "market_income": 3,
    "has_irrigation": False,
    "machinery": [],
}

RECOMMEND_BODY_EXAMPLE: dict[str, object] = {
    "field_id": "fld_cole_o_id_do_analyze",
    "priorities": DEMO_PRIORITIES_JSON,
}

SIMULATE_BODY_EXAMPLE: dict[str, object] = {
    **RECOMMEND_BODY_EXAMPLE,
    "delta_precip_pct": -25,
    "delta_temp_c": 2,
}


def demo_farmer_priorities() -> "FarmerPriorities":
    return FarmerPriorities.model_validate(DEMO_PRIORITIES_JSON)


class FarmerPriorities(BaseModel):
    water_savings: int = Field(default=5, ge=0, le=5)
    soil_organic_matter: int = Field(default=3, ge=0, le=5)
    erosion_control: int = Field(default=4, ge=0, le=5)
    pest_cycle_break: int = Field(default=3, ge=0, le=5)
    forage_value: int = Field(default=2, ge=0, le=5)
    market_income: int = Field(default=3, ge=0, le=5)
    has_irrigation: bool = False
    machinery: list[str] = Field(default_factory=list)


class FieldAnalyzeRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "example": {
                "name": "Alfafa Nevada",
                "current_crop": "Alfafa",
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [
                        [
                            [-118.78, 39.47],
                            [-118.77, 39.47],
                            [-118.77, 39.48],
                            [-118.78, 39.48],
                            [-118.78, 39.47],
                        ]
                    ],
                },
            }
        }
    )

    name: str = "Talhão"
    current_crop: str = Field(min_length=1)
    geometry: dict[str, Any]

    @field_validator("geometry")
    @classmethod
    def polygon_or_feature(cls, value: dict[str, Any]) -> dict[str, Any]:
        geo_type = value.get("type")
        if geo_type == "Feature":
            geometry = value.get("geometry") or {}
            geo_type = geometry.get("type")
        if geo_type != "Polygon":
            raise ValueError("geometry must be a GeoJSON Polygon or a Feature with a Polygon")
        return value


class FieldAnalyzeResponse(BaseModel):
    field_id: str
    name: str
    current_crop: str
    placeholder: bool = True
    message: str
    summary: HarmonizedSummary
    health: DiagnosticHealth
    analysis_meta: AnalysisMeta


class FieldListItem(BaseModel):
    id: str
    name: str
    current_crop: str


class DiagnosticsResponse(BaseModel):
    field_id: str
    placeholder: bool = True
    message: str
    summary: HarmonizedSummary
    health: DiagnosticHealth
    analysis_meta: AnalysisMeta


class RecommendRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [RECOMMEND_BODY_EXAMPLE],
        }
    )

    field_id: str = Field(min_length=1, description="ID retornado pelo POST /fields/analyze")
    priorities: FarmerPriorities = Field(
        description="Prioridades do produtor (sliders 0–5). Obrigatório no app; exemplo pré-preenchido no Swagger."
    )


class SimulationRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [SIMULATE_BODY_EXAMPLE],
        }
    )

    field_id: str = Field(min_length=1, description="ID retornado pelo POST /fields/analyze")
    delta_precip_pct: float = Field(
        default=0,
        ge=-30,
        le=30,
        description="Variação percentual na chuva anual (ex.: -25).",
    )
    delta_temp_c: float = Field(
        default=0,
        ge=0,
        le=4,
        description="Aumento de temperatura em °C para recálculo da ET (ex.: 2).",
    )
    priorities: FarmerPriorities = Field(
        default_factory=demo_farmer_priorities,
        description="Mesmas prioridades do Recommend; omitir na API usa o perfil demo Nevada.",
    )


class SimulationResponse(BaseModel):
    field_id: str
    delta_precip_pct: float
    delta_temp_c: float
    placeholder: bool = True
    message: str
    strategies: list[RotationStrategy]


class LatestSimulationResponse(BaseModel):
    id: int
    created_at: datetime
    simulation: SimulationResponse


class GlossaryResponse(BaseModel):
    term: str
    explanation: str
    satellite_vs_in_situ: str
    placeholder: bool = True


def empty_summary() -> HarmonizedSummary:
    return HarmonizedSummary(
        annual_precip_mm=0,
        annual_et_demand_mm=0,
        water_balance_deficit_mm=0,
        smap_rootzone_anomaly_z=0,
        bare_field_months=[],
        soil_profile=SoilProfile(
            mapunit_name="",
            organic_matter_pct=0,
            available_water_capacity_cm_cm=0,
            drainage_class="",
            hydrologic_group="",
            erosion_k_factor=0,
        ),
    )


_PLACEHOLDER_MESSAGE = (
    "Resposta de exemplo (Churchill County, NV) do relatório de arquitetura. "
    "O motor de fusão e o MCDA ainda não calculam este talhão."
)


def placeholder_strategies() -> list[RotationStrategy]:
    baseline = RotationStrategy(
        strategy_id="rot_baseline",
        name="Estratégia 1 (Atual): Alfafa Contínua (5+ anos) com Pousio na Reforma",
        is_baseline=True,
        sequence=["Alfafa (Ano 1-4)", "Pousio de Reforma (Outono/Inverno)", "Alfafa (Replantio)"],
        metrics_radar=MetricsRadar(
            water_efficiency_score=38,
            soil_health_organic_matter_score=65,
            nitrogen_fixation_score=85,
            erosion_protection_score=60,
            pest_cycle_disruption_score=30,
            market_viability_score=88,
        ),
        explanation=RotationExplanation(
            why_suggested=(
                "Representa o manejo histórico atual identificado pelo USDA CDL "
                "no talhão para servir como linha de base comparativa."
            ),
            supporting_evidence=[
                "OpenET e ECOSTRESS indicam demanda evaporativa de 1.180 mm/ano no verão com índice ESI caindo para 0.42 em julho-agosto.",
                "SMAP L4 mostra anomalia de umidade radicular de -1.45 desvios-padrão nos últimos 3 verões.",
                "Sentinel-2/Landsat detectam 4 meses de solo exposto (NDVI < 0.20) no ano de reforma do estande.",
            ],
            expected_benefits=[
                "Alta fixação biológica de nitrogênio e cobertura perene durante os anos estabelecidos.",
                "Mercado local consolidado para feno de alfafa (USDA AMS Market News).",
            ],
            information_gaps_and_uncertainty=[
                "O pixel do SMAP (9 km) captura a média regional do vale irrigado e não mede a umidade exata por válvula de irrigação.",
                "Não há dados de satélite sobre compactação subsuperficial ou nematoides de galha acumulados.",
            ],
            risks_requiring_local_review=[
                "Autotoxicidade alelopática da alfafa ao replantar sem cultura intermediária.",
                "Alto consumo hídrico em anos de corte de alocação de água superficial (USGS NWIS).",
            ],
        ),
    )
    water = RotationStrategy(
        strategy_id="rot_water_resilient",
        name="Estratégia 2 (Economia de Água & Quebra de Pragas): Alfafa → Triticale/Cevada de Inverno → Sorgo Forrageiro BMR",
        is_baseline=False,
        sequence=[
            "Alfafa (Encerramento)",
            "Triticale de Inverno (Out-Abr)",
            "Sorgo Forrageiro Tolerante à Seca (Mai-Set)",
            "Retorno à Alfafa ou Leguminosa",
        ],
        metrics_radar=MetricsRadar(
            water_efficiency_score=86,
            soil_health_organic_matter_score=82,
            nitrogen_fixation_score=68,
            erosion_protection_score=92,
            pest_cycle_disruption_score=90,
            market_viability_score=80,
        ),
        explanation=RotationExplanation(
            why_suggested=(
                "Alinha-se à prioridade máxima de redução de uso de água e eliminação "
                "do período de solo exposto no inverno, mantendo produção de forragem."
            ),
            supporting_evidence=[
                "NASA POWER e PRISM mostram que o cultivo de inverno aproveita a janela de menor déficit de pressão de vapor e as chuvas de inverno.",
                "FAO GAEZ v4 e OpenET confirmam redução de cerca de 32% na evapotranspiração sazonal com Sorgo e Triticale frente à alfafa em pleno verão.",
            ],
            expected_benefits=[
                "Aproveita o crédito de nitrogênio deixado pela alfafa sem exigir adubação nitrogenada pesada.",
                "Elimina a janela de solo exposto de novembro a fevereiro.",
                "Interrompe o ciclo de pragas e plantas daninhas perenes da alfafa.",
            ],
            information_gaps_and_uncertainty=[
                "A condutividade elétrica da água de irrigação local não é visível via satélite.",
                "Preços regionais de silagem de triticale têm menor liquidez pública no USDA AMS do que a alfafa.",
            ],
            risks_requiring_local_review=[
                "Validar com agrônomo local o risco de acúmulo de nitratos ou ácido prússico no sorgo forrageiro em caso de geada precoce.",
            ],
        ),
    )
    soil = RotationStrategy(
        strategy_id="rot_soil_income",
        name="Estratégia 3 (Solo, Cobertura de Inverno e Renda): Alfafa → Trigo de Inverno → Leguminosa de Mercado",
        is_baseline=False,
        sequence=[
            "Alfafa (Encerramento)",
            "Trigo de Inverno (cobertura e grão)",
            "Leguminosa de mercado (soja ou alfafa replantada)",
        ],
        metrics_radar=MetricsRadar(
            water_efficiency_score=70,
            soil_health_organic_matter_score=84,
            nitrogen_fixation_score=78,
            erosion_protection_score=88,
            pest_cycle_disruption_score=74,
            market_viability_score=76,
        ),
        explanation=RotationExplanation(
            why_suggested=(
                "Terceira estratégia exigida pelo desafio: regeneração de solo, "
                "cobertura de inverno e renda, ainda sem cálculo MCDA."
            ),
            supporting_evidence=[
                "Valores ilustrativos do relatório de arquitetura, não derivados de uma série NASA deste talhão.",
            ],
            expected_benefits=[
                "Mantém o solo coberto no inverno e abre uma cultura de grão com mercado regional.",
            ],
            information_gaps_and_uncertainty=[
                "Produtividade de condado (NASS) e preço (AMS) ainda não foram consultados.",
            ],
            risks_requiring_local_review=[
                "Confirmar com o agrônomo local se o maquinário da fazenda cobre trigo e a leguminosa sugerida.",
            ],
        ),
    )
    return [baseline, water, soil]


def placeholder_recommendation(field_id: str) -> RotationRecommendation:
    return RotationRecommendation(
        field_id=field_id,
        placeholder=True,
        message=_PLACEHOLDER_MESSAGE,
        location=Location(lat=39.473, lon=-118.777, state="NV", county="Churchill"),
        harmonized_summary=HarmonizedSummary(
            annual_precip_mm=132.4,
            annual_et_demand_mm=1180.0,
            water_balance_deficit_mm=-1047.6,
            smap_rootzone_anomaly_z=-1.45,
            bare_field_months=["November", "December", "January", "February"],
            soil_profile=SoilProfile(
                mapunit_name="Dia loam, 0 to 2 percent slopes",
                organic_matter_pct=1.2,
                available_water_capacity_cm_cm=0.16,
                drainage_class="Well drained",
                hydrologic_group="B",
                erosion_k_factor=0.32,
            ),
        ),
        strategies=placeholder_strategies(),
    )
