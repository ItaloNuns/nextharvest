from app.services.stage1_features import (
    extract_stage1_features,
    summarize_stage1_from_power_raw,
    theil_sen_slope,
)


def test_theil_sen_slope() -> None:
    assert theil_sen_slope([2020, 2021, 2022, 2023], [10, 12, 14, 16]) == 2.0


def test_extract_stage1_features_and_openet_override() -> None:
    power = {"T2M_MAX": {}, "T2M_MIN": {}, "PRECTOTCORR": {}, "EVPTRNS": {}, "GWETROOT": {}}
    for yr_idx, yr in enumerate([2023, 2024, 2025]):
        for mo in (1, 7):
            day = f"{yr}{mo:02d}15"
            power["T2M_MAX"][day] = 36.0 if (mo == 7 and yr >= 2024) else 25.0
            power["T2M_MIN"][day] = -2.0 if (mo == 1 and yr == 2023) else 5.0
            power["PRECTOTCORR"][day] = 50.0 if mo == 1 else 5.0
            power["EVPTRNS"][day] = 10.0 if mo == 1 else 120.0
            power["GWETROOT"][day] = 0.50 - (0.10 * yr_idx if mo == 7 else 0.0)

    optical = {1: {"ndvi": 0.18, "scl": 5}, 7: {"ndvi": 0.72, "scl": 4}}
    res = extract_stage1_features(
        power,
        monthly_optical=optical,
        openet_monthly_mm={7: 185.0},
        kwfact=0.32,
        slope_pct=5.0,
    )

    assert res["latest_year"] == 2025
    assert res["soil_moisture_anomaly_z"][7] < -1.0
    assert res["crop_water_deficit_mm"][1] == 40.0
    assert res["crop_water_deficit_mm"][7] == -180.0
    assert res["bare_soil_months"] == [1]
    assert res["seasonal_erosion_risk"][1] > res["seasonal_erosion_risk"][7]
    assert res["climate_trends_per_year"]["hot_days_above_35c_slope"] == 0.5
    assert res["climate_trends_per_year"]["frost_free_days_slope"] == 0.5


def test_summarize_stage1_from_power_raw() -> None:
    raw = {
        "properties": {
            "parameter": {
                "PRECTOTCORR": {"20250115": 10.0, "20250715": 2.0},
                "GWETROOT": {"20250115": 0.55, "20250715": 0.20},
                "EVPTRNS": {"20250115": 25.0, "20250715": 8.0},
            }
        }
    }
    z_val, bare_months = summarize_stage1_from_power_raw(raw, kwfact=0.32)
    assert z_val == -1.0
    assert bare_months == ["July"]
