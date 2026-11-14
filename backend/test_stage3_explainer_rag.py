from stage2_rotation_mcda import recommend_rotations
from stage3_explainer_rag import (
    explain_scientific_term,
    generate_stage3_explanations,
    retrieve_agronomic_snippets,
)

REQUIRED_KEYS = {
    "why_suggested",
    "supporting_evidence",
    "expected_benefits",
    "information_gaps_and_uncertainty",
    "risks_requiring_local_review",
}


def test_rag_retrieval():
    snippets = retrieve_agronomic_snippets(["alfalfa", "sorghum"], ["bare"])
    assert len(snippets) == 3
    assert any("Rhizobium" in s or "NDVI" in s for s in snippets)


def test_stage2_to_stage3_pipeline():
    stage1_mock = {
        "soil_moisture_anomaly_z": {1: 0.2, 7: -1.6},
        "crop_water_deficit_mm": {1: 15.0, 7: -135.0},
        "bare_soil_months": [11, 12, 1],
        "climate_trends_per_year": {"hot_days_above_35c_slope": 0.45, "frost_free_days_slope": 0.3},
    }
    stage2 = recommend_rotations(["alfalfa", "alfalfa"], stage1_mock, field_area_ha=15.0)
    res = generate_stage3_explanations(stage1_mock, stage2, api_key=None)

    assert len(res["strategies"]) == 3
    for strat in res["strategies"]:
        exp = strat["explanation"]
        assert set(exp.keys()) == REQUIRED_KEYS
        assert len(exp["supporting_evidence"]) >= 2
        assert len(exp["information_gaps_and_uncertainty"]) >= 1
        assert len(exp["risks_requiring_local_review"]) >= 1
    assert "não substitui" in res["disclaimer"]


def test_explain_glossary():
    assert "0,22" in explain_scientific_term("NDVI")
    assert "satélite" in explain_scientific_term("satelite_vs_solo").lower()
