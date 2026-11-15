from app.schemas.rotation_models import HarmonizedSummary, SoilProfile
from app.services.analysis_meta import from_stored


def _summary(*, precip: float = 15.0, et: float = 200.0, mapunit: str = "Dia loam") -> HarmonizedSummary:
    return HarmonizedSummary(
        annual_precip_mm=precip,
        annual_et_demand_mm=et,
        water_balance_deficit_mm=round(precip - et, 2),
        smap_rootzone_anomaly_z=0,
        bare_field_months=[],
        soil_profile=SoilProfile(
            mapunit_name=mapunit,
            organic_matter_pct=1.2,
            available_water_capacity_cm_cm=0.16,
            drainage_class="Well drained",
            hydrologic_group="B",
            erosion_k_factor=0.32,
        ),
    )


def test_from_stored_uses_persisted_openet() -> None:
    meta = from_stored(
        {"climate_ok": True, "soil_ok": True, "et_source": "openet", "failures": ["OpenET: timeout"]},
        _summary(),
    )
    assert meta.et_source == "openet"
    assert meta.failures == ["OpenET: timeout"]


def test_from_stored_without_meta_does_not_invent_openet() -> None:
    meta = from_stored(None, _summary(et=200.0))
    assert meta.et_source == "power"
    assert meta.climate_ok is True
    assert meta.soil_ok is True
    assert meta.failures == []


def test_from_stored_without_et_is_none() -> None:
    meta = from_stored(None, _summary(et=0.0, mapunit=""))
    assert meta.et_source == "none"
    assert meta.climate_ok is True
    assert meta.soil_ok is False
