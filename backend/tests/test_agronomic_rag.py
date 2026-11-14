from app.schemas.rotation_models import HarmonizedSummary, SoilProfile
from app.services.agronomic_rag import (
    extra_tags_from_summary,
    retrieve_agronomic_snippets,
)


def test_retrieve_prefers_legume_and_nitrogen_snippets() -> None:
    snippets = retrieve_agronomic_snippets(["alfalfa"], extra_tags=["nitrogen"])
    assert len(snippets) == 3
    assert any("Leguminosas" in text for text in snippets)


def test_retrieve_prefers_drought_snippets_for_sorghum() -> None:
    snippets = retrieve_agronomic_snippets(["sorghum"], extra_tags=["drought", "water"])
    assert any("FAO GAEZ" in text or "Sorgo" in text for text in snippets)


def test_extra_tags_mark_bare_and_drought() -> None:
    summary = HarmonizedSummary(
        annual_precip_mm=100.0,
        annual_et_demand_mm=400.0,
        water_balance_deficit_mm=-300.0,
        smap_rootzone_anomaly_z=0,
        bare_field_months=["January"],
        soil_profile=SoilProfile(
            mapunit_name="Dia loam",
            organic_matter_pct=1.2,
            available_water_capacity_cm_cm=0.16,
            drainage_class="Well drained",
            hydrologic_group="B",
            erosion_k_factor=0.32,
        ),
    )
    tags = extra_tags_from_summary(summary)
    assert "bare" in tags
    assert "drought" in tags
    assert "water" in tags
