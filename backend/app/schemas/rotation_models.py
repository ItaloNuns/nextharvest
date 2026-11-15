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

    name: str = "Field"
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

    field_id: str = Field(min_length=1, description="ID returned by POST /fields/analyze")
    priorities: FarmerPriorities = Field(
        description="Farmer priorities (sliders 0–5). Required in the app; Swagger pre-fills an example."
    )


class SimulationRequest(BaseModel):
    model_config = ConfigDict(
        json_schema_extra={
            "examples": [SIMULATE_BODY_EXAMPLE],
        }
    )

    field_id: str = Field(min_length=1, description="ID returned by POST /fields/analyze")
    delta_precip_pct: float = Field(
        default=0,
        ge=-30,
        le=30,
        description="Percent change in annual rainfall (e.g. -25).",
    )
    delta_temp_c: float = Field(
        default=0,
        ge=0,
        le=4,
        description="Temperature increase in °C for ET recalculation (e.g. 2).",
    )
    priorities: FarmerPriorities = Field(
        default_factory=demo_farmer_priorities,
        description="Same priorities as Recommend; omit to use the Nevada demo profile.",
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
    "Sample response (Churchill County, NV) from the architecture report. "
    "The fusion engine and MCDA do not compute this field yet."
)


def placeholder_strategies() -> list[RotationStrategy]:
    baseline = RotationStrategy(
        strategy_id="rot_baseline",
        name="Strategy 1 (Current): Continuous alfalfa (5+ years) with renovation fallow",
        is_baseline=True,
        sequence=["Alfalfa (years 1-4)", "Renovation fallow (fall/winter)", "Alfalfa (replant)"],
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
                "Represents current historical management identified by USDA CDL "
                "on the field as a comparative baseline."
            ),
            supporting_evidence=[
                "OpenET and ECOSTRESS indicate 1,180 mm/yr evaporative demand in summer with ESI dropping to 0.42 in Jul–Aug.",
                "SMAP L4 shows root-zone moisture anomaly of −1.45 standard deviations over the last 3 summers.",
                "Sentinel-2/Landsat detect 4 bare-soil months (NDVI < 0.20) in the stand renovation year.",
            ],
            expected_benefits=[
                "High biological nitrogen fixation and perennial cover during established years.",
                "Established local market for alfalfa hay (USDA AMS Market News).",
            ],
            information_gaps_and_uncertainty=[
                "The SMAP pixel (9 km) captures regional irrigated-valley averages, not moisture per irrigation valve.",
                "No satellite data on subsurface compaction or accumulated root-knot nematodes.",
            ],
            risks_requiring_local_review=[
                "Alfalfa autotoxicity when replanting without an intermediate crop.",
                "High water use in years with surface-water allocation cuts (USGS NWIS).",
            ],
        ),
    )
    water = RotationStrategy(
        strategy_id="rot_water_resilient",
        name="Strategy 2 (Water savings & pest break): Alfalfa → winter triticale → forage sorghum",
        is_baseline=False,
        sequence=[
            "Alfalfa (termination)",
            "Winter triticale (Oct–Apr)",
            "Drought-tolerant forage sorghum (May–Sep)",
            "Return to alfalfa or legume",
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
                "Aligns with top priority to cut water use and remove winter bare-soil "
                "periods while keeping forage production."
            ),
            supporting_evidence=[
                "NASA POWER and PRISM show winter crops use the window of lower vapor-pressure deficit and winter rains.",
                "FAO GAEZ v4 and OpenET confirm ~32% lower seasonal ET with sorghum and triticale vs full-summer alfalfa.",
            ],
            expected_benefits=[
                "Uses nitrogen credit from alfalfa without heavy synthetic N fertilizer.",
                "Removes the November–February bare-soil window.",
                "Breaks perennial alfalfa pest and weed cycles.",
            ],
            information_gaps_and_uncertainty=[
                "Local irrigation water electrical conductivity is not visible from satellites.",
                "Regional triticale silage prices have less public USDA AMS liquidity than alfalfa.",
            ],
            risks_requiring_local_review=[
                "Confirm with a local agronomist nitrate or prussic-acid risk in forage sorghum after early frost.",
            ],
        ),
    )
    soil = RotationStrategy(
        strategy_id="rot_soil_income",
        name="Strategy 3 (Soil, winter cover & income): Alfalfa → winter wheat → market legume",
        is_baseline=False,
        sequence=[
            "Alfalfa (termination)",
            "Winter wheat (cover and grain)",
            "Market legume (soybeans or replanted alfalfa)",
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
                "Third strategy required by the challenge: soil regeneration, "
                "winter cover and income—illustrative without full MCDA."
            ),
            supporting_evidence=[
                "Illustrative values from the architecture report, not from a NASA series for this field.",
            ],
            expected_benefits=[
                "Keeps soil covered in winter and adds a grain crop with regional market.",
            ],
            information_gaps_and_uncertainty=[
                "County yield (NASS) and price (AMS) were not queried.",
            ],
            risks_requiring_local_review=[
                "Confirm with a local agronomist whether farm machinery covers wheat and the suggested legume.",
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
