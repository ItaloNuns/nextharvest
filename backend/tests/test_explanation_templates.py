from app.schemas.rotation_models import FarmerPriorities, HarmonizedSummary, MetricsRadar, SoilProfile
from app.services.explanation_templates import explain_strategy


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


def test_evidence_uses_real_precip_and_does_not_invent_satellite_metrics() -> None:
    radar = MetricsRadar(
        water_efficiency_score=80,
        soil_health_organic_matter_score=70,
        nitrogen_fixation_score=60,
        erosion_protection_score=75,
        pest_cycle_disruption_score=70,
        market_viability_score=70,
    )
    baseline = MetricsRadar(
        water_efficiency_score=40,
        soil_health_organic_matter_score=50,
        nitrogen_fixation_score=80,
        erosion_protection_score=50,
        pest_cycle_disruption_score=30,
        market_viability_score=80,
    )
    explanation = explain_strategy(
        role="water",
        sequence_label="Sorgo → Grão-de-Bico → Girassol",
        current_crop="Alfafa",
        summary=_summary(),
        priorities=FarmerPriorities(
            water_savings=5,
            soil_organic_matter=2,
            erosion_control=3,
            pest_cycle_break=2,
            forage_value=1,
            market_income=2,
            has_irrigation=False,
        ),
        radar=radar,
        baseline_radar=baseline,
        field_area_ha=12.0,
    )
    evidence = " ".join(explanation.supporting_evidence)
    gaps = " ".join(explanation.information_gaps_and_uncertainty)
    blob = evidence + " " + gaps
    assert "15.0 mm" in evidence
    assert "Dia loam" in evidence
    assert "NASS" in gaps
    assert "OpenET" not in blob
    assert "ainda não entram" in evidence
    assert "12.0 ha" in gaps


def test_evidence_cites_et_and_nass_when_present() -> None:
    summary = _summary()
    summary = summary.model_copy(
        update={"annual_et_demand_mm": 200.0, "water_balance_deficit_mm": -185.0}
    )
    radar = MetricsRadar(
        water_efficiency_score=80,
        soil_health_organic_matter_score=70,
        nitrogen_fixation_score=60,
        erosion_protection_score=75,
        pest_cycle_disruption_score=70,
        market_viability_score=70,
    )
    explanation = explain_strategy(
        role="water",
        sequence_label="Sorgo",
        current_crop="Alfafa",
        summary=summary,
        priorities=FarmerPriorities(
            water_savings=5,
            soil_organic_matter=2,
            erosion_control=3,
            pest_cycle_break=2,
            forage_value=1,
            market_income=2,
        ),
        radar=radar,
        baseline_radar=radar,
        nass_used=True,
        state="NV",
        county="Churchill",
    )
    evidence = " ".join(explanation.supporting_evidence)
    gaps = " ".join(explanation.information_gaps_and_uncertainty)
    assert "200.0 mm" in evidence
    assert "Churchill" in evidence
    assert "QuickStats" in evidence
    assert "ainda não foram consultados" not in gaps
    assert "AMS" in gaps
