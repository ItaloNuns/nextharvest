from app.schemas.rotation_models import FarmerPriorities, HarmonizedSummary, SoilProfile
from app.services.crop_catalog import mean_kc, resolve_crop
from app.services.rotation_engine import RotationEngine


def _summary() -> HarmonizedSummary:
    return HarmonizedSummary(
        annual_precip_mm=15.0,
        annual_et_demand_mm=0,
        water_balance_deficit_mm=15.0,
        smap_rootzone_anomaly_z=0,
        bare_field_months=[],
        soil_profile=SoilProfile(
            mapunit_name="Dia loam, 0 to 2 percent slopes",
            organic_matter_pct=1.2,
            available_water_capacity_cm_cm=0.16,
            drainage_class="Well drained",
            hydrologic_group="B",
            erosion_k_factor=0.32,
        ),
    )


def _priorities(**overrides: object) -> FarmerPriorities:
    payload = {
        "water_savings": 5,
        "soil_organic_matter": 3,
        "erosion_control": 4,
        "pest_cycle_break": 3,
        "forage_value": 2,
        "market_income": 3,
        "has_irrigation": False,
        "machinery": [],
    }
    payload.update(overrides)
    return FarmerPriorities.model_validate(payload)


def _codes(sequence: list[str]) -> tuple[str, ...]:
    codes = tuple(resolve_crop(label) or label for label in sequence)
    return codes


def test_engine_returns_three_distinct_strategies() -> None:
    strategies = RotationEngine().recommend(_summary(), _priorities(), "Alfafa")
    assert len(strategies) == 3
    assert strategies[0].is_baseline is True
    assert strategies[0].sequence[0] == "Alfafa"
    assert strategies[1].is_baseline is False
    assert strategies[2].is_baseline is False
    assert strategies[1].sequence != strategies[2].sequence
    ids = {item.strategy_id for item in strategies}
    assert ids == {"rot_baseline", "rot_water_resilient", "rot_soil_market"}


def test_water_alternative_has_lower_kc_than_alfalfa() -> None:
    strategies = RotationEngine().recommend(
        _summary(),
        _priorities(water_savings=5, has_irrigation=False),
        "Alfafa",
    )
    water_codes = _codes(strategies[1].sequence)
    assert mean_kc(water_codes) < mean_kc(("alfalfa",))
    assert strategies[1].metrics_radar.water_efficiency_score > strategies[0].metrics_radar.water_efficiency_score


def test_unknown_crop_still_returns_three_strategies() -> None:
    strategies = RotationEngine().recommend(_summary(), _priorities(), "Batata")
    assert len(strategies) == 3
    assert strategies[0].is_baseline is True
    assert "Batata" in strategies[0].sequence[0]
