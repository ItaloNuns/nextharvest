import pytest
from stage2_rotation_mcda import (
    fetch_nass_crop_scores,
    has_valid_family_succession,
    recommend_rotations,
    score_sequence,
)


def test_botanical_family_succession():
    assert not has_valid_family_succession(("corn", "sorghum"))  # both Poaceae
    assert has_valid_family_succession(("corn", "soybeans", "winter_wheat"))


def test_recommend_three_strategies_and_uncertainty():
    stage1_mock = {
        "crop_water_deficit_mm": {1: 20.0, 7: -140.0},
        "bare_soil_months": [11, 12, 1, 2],
    }
    res = recommend_rotations(
        current_sequence=["corn", "corn"],
        stage1=stage1_mock,
        field_area_ha=20.0,
        cloud_cover_pct=25.0,
        has_local_soil_lab=False,
    )
    strats = res["strategies"]
    assert len(strats) == 3
    assert strats[0]["is_baseline"] is True
    assert strats[1]["codes"] != strats[2]["codes"]
    assert strats[1]["metrics_radar"]["water_efficiency_score"] > strats[0]["metrics_radar"]["water_efficiency_score"]
    assert strats[1]["metrics_radar"]["pest_cycle_disruption_score"] > strats[0]["metrics_radar"]["pest_cycle_disruption_score"]
    assert res["uncertainty"]["uncertainty_score_0_100"] > 50
    assert len(res["uncertainty"]["reasons"]) == 3


def test_unknown_crop_raises():
    with pytest.raises(ValueError):
        score_sequence(("unknown_crop",), {})


def test_nass_no_key_and_market_overrides(monkeypatch):
    monkeypatch.delenv("NASS_API_KEY", raising=False)
    assert fetch_nass_crop_scores("NV", api_key=None) == {}

    res = recommend_rotations(
        current_sequence=["alfalfa"],
        stage1={"crop_water_deficit_mm": {7: -50.0}, "bare_soil_months": []},
        market_overrides={"alfalfa": 99.0},
    )
    assert res["strategies"][0]["metrics_radar"]["market_viability_score"] == 99
