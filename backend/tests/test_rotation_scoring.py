from app.schemas.rotation_models import HarmonizedSummary, SoilProfile
from app.services.rotation_engine import apply_climate_delta, score_sequence


def _summary(*, precip: float = 15.0, om: float = 1.2, k: float = 0.32) -> HarmonizedSummary:
    return HarmonizedSummary(
        annual_precip_mm=precip,
        annual_et_demand_mm=0,
        water_balance_deficit_mm=precip,
        smap_rootzone_anomaly_z=0,
        bare_field_months=[],
        soil_profile=SoilProfile(
            mapunit_name="Dia loam, 0 to 2 percent slopes",
            organic_matter_pct=om,
            available_water_capacity_cm_cm=0.16,
            drainage_class="Well drained",
            hydrologic_group="B",
            erosion_k_factor=k,
        ),
    )


def test_same_sequence_same_scores() -> None:
    summary = _summary()
    seq = ("sorghum", "chickpea", "sunflower")
    assert score_sequence(seq, summary) == score_sequence(seq, summary)


def test_winter_cover_beats_corn_monoculture_on_erosion() -> None:
    summary = _summary()
    corn = score_sequence(("corn", "corn"), summary)
    covered = score_sequence(("corn", "rye_vetch_cover", "soybeans"), summary)
    assert covered["erosion_protection_score"] > corn["erosion_protection_score"]


def test_low_kc_beats_alfalfa_on_water_when_rain_is_scarce() -> None:
    summary = _summary(precip=15.0)
    alfalfa = score_sequence(("alfalfa",), summary)
    sorghum = score_sequence(("sorghum", "chickpea", "sunflower"), summary)
    assert sorghum["water_efficiency_score"] > alfalfa["water_efficiency_score"]


def test_market_override_changes_viability() -> None:
    summary = _summary()
    catalog = score_sequence(("alfalfa",), summary)
    overridden = score_sequence(("alfalfa",), summary, market_overrides={"alfalfa": 20.0})
    assert overridden["market_viability_score"] == 20
    assert catalog["market_viability_score"] != overridden["market_viability_score"]


def test_climate_delta_lowers_precip_and_raises_et() -> None:
    summary = _summary(precip=100.0)
    summary = summary.model_copy(update={"annual_et_demand_mm": 50.0, "water_balance_deficit_mm": 50.0})
    adjusted = apply_climate_delta(summary, delta_precip_pct=-25, delta_temp_c=2)
    assert adjusted.annual_precip_mm == 75.0
    assert adjusted.annual_et_demand_mm == 55.0
    assert adjusted.water_balance_deficit_mm == 20.0
