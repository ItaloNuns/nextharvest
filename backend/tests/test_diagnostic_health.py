from app.schemas.rotation_models import HarmonizedSummary, SoilProfile, empty_summary
from app.services.diagnostic_health import assess_diagnostic_health


def _soil(
    *,
    mapunit: str = "Dia loam, 0 to 2 percent slopes",
    om: float = 1.2,
    k_factor: float = 0.32,
) -> SoilProfile:
    return SoilProfile(
        mapunit_name=mapunit,
        organic_matter_pct=om,
        available_water_capacity_cm_cm=0.16,
        drainage_class="Well drained",
        hydrologic_group="B",
        erosion_k_factor=k_factor,
    )


def _summary(
    *,
    precip: float = 15.0,
    et: float = 200.0,
    soil: SoilProfile | None = None,
) -> HarmonizedSummary:
    profile = soil or _soil()
    return HarmonizedSummary(
        annual_precip_mm=precip,
        annual_et_demand_mm=et,
        water_balance_deficit_mm=round(precip - et, 2),
        smap_rootzone_anomaly_z=0,
        bare_field_months=[],
        soil_profile=profile,
    )


def _by_id(health):
    return {item.id: item for item in health.dimensions}


def test_nevada_like_summary_water_warning_soil_warning() -> None:
    health = assess_diagnostic_health(_summary(precip=15.0, et=200.0), placeholder=False)
    dims = _by_id(health)
    assert dims["water"].status == "warning"
    assert dims["soil"].status == "warning"
    assert dims["sources"].status == "ok"
    assert health.overall == "warning"
    assert health.data_quality == "ok"


def test_water_critical_when_deficit_at_or_below_200() -> None:
    health = assess_diagnostic_health(_summary(precip=15.0, et=250.0), placeholder=False)
    assert _by_id(health)["water"].status == "critical"
    assert health.overall == "critical"


def test_empty_placeholder_is_critical_data_quality() -> None:
    health = assess_diagnostic_health(empty_summary(), placeholder=True)
    dims = _by_id(health)
    assert health.data_quality == "critical"
    assert dims["sources"].status == "critical"
    assert dims["soil"].status == "ok"


def test_soil_ok_when_om_and_k_are_comfortable() -> None:
    soil = _soil(om=2.4, k_factor=0.2)
    health = assess_diagnostic_health(_summary(precip=450.0, et=400.0, soil=soil), placeholder=False)
    dims = _by_id(health)
    assert dims["soil"].status == "ok"
    assert dims["water"].status == "ok"
    assert health.overall == "ok"


def test_missing_et_marks_sources_warning() -> None:
    health = assess_diagnostic_health(_summary(precip=250.0, et=0.0), placeholder=False)
    dims = _by_id(health)
    assert dims["sources"].status == "warning"
    assert health.data_quality == "warning"
    assert dims["water"].status == "warning"
