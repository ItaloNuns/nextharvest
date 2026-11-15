"""Stage 1 biophysical feature extraction (root-zone moisture Z-score, CWD, bare-soil months, Theil-Sen trends)."""

from __future__ import annotations

from collections import defaultdict
import calendar
from statistics import mean, median, pstdev
from typing import Any


def theil_sen_slope(years: list[int], values: list[float]) -> float:
    slopes = [
        (values[j] - values[i]) / (years[j] - years[i])
        for i in range(len(years))
        for j in range(i + 1, len(years))
        if years[j] != years[i]
    ]
    return round(median(slopes), 4) if slopes else 0.0


def extract_stage1_features(
    power_params: dict[str, dict[str, float]],
    monthly_optical: dict[int, dict[str, float]] | None = None,
    openet_monthly_mm: dict[int, float] | None = None,
    kwfact: float = 0.30,
    slope_pct: float = 2.0,
) -> dict[str, Any]:
    """Compute Stage 1 biophysical features from daily NASA POWER series and optional monthly NDVI/SCL/OpenET."""
    tmax = power_params.get("T2M_MAX") or {}
    tmin = power_params.get("T2M_MIN") or {}
    precip = power_params.get("PRECTOTCORR") or {}
    et = power_params.get("EVPTRNS") or {}
    sm = power_params.get("GWETROOT") or {}

    month_sm: dict[int, dict[int, list[float]]] = defaultdict(lambda: defaultdict(list))
    month_p: dict[int, dict[int, float]] = defaultdict(lambda: defaultdict(float))
    month_et: dict[int, dict[int, float]] = defaultdict(lambda: defaultdict(float))
    year_hot: dict[int, int] = defaultdict(int)
    year_frost_free: dict[int, int] = defaultdict(int)

    for day, p_val in precip.items():
        if p_val is None or sm.get(day) is None:
            continue
        p_num, sm_num = float(p_val), float(sm[day])
        if p_num <= -900 or sm_num <= -900:
            continue
        yr, mo = int(day[:4]), int(day[4:6])
        month_sm[mo][yr].append(sm_num)
        month_p[mo][yr] += p_num
        et_val = float(et.get(day, -999.0))
        tmax_val = float(tmax.get(day, -999.0))
        tmin_val = float(tmin.get(day, -999.0))
        month_et[mo][yr] += et_val if et_val > -900 else max(0.0, (tmax_val if tmax_val > -900 else 0.0) * 0.15)
        if tmax_val > 35.0:
            year_hot[yr] += 1
        if tmin_val > -900 and tmin_val >= 0.0:
            year_frost_free[yr] += 1

    all_years = sorted({y for m in month_sm.values() for y in m})
    if not all_years:
        return {
            "latest_year": 0,
            "soil_moisture_anomaly_z": {},
            "crop_water_deficit_mm": {},
            "bare_soil_months": [],
            "seasonal_erosion_risk": {},
            "climate_trends_per_year": {"hot_days_above_35c_slope": 0.0, "frost_free_days_slope": 0.0},
        }

    latest_yr = max(all_years)
    sm_anomaly_z: dict[int, float] = {}
    cwd_mm: dict[int, float] = {}
    bare_months: list[int] = []
    erosion_risk: dict[int, float] = {}

    for mo in range(1, 13):
        yr_means = {y: mean(vals) for y, vals in month_sm[mo].items() if vals}
        if not yr_means:
            continue
        mu = mean(yr_means.values())
        sd = pstdev(yr_means.values())
        cur_sm = yr_means.get(latest_yr, mu)
        sm_anomaly_z[mo] = round((cur_sm - mu) / sd, 2) if sd > 1e-6 else 0.0

        avg_p = mean(month_p[mo].values())
        avg_et = (openet_monthly_mm or {}).get(mo, mean(month_et[mo].values()))
        cwd_mm[mo] = round(avg_p - avg_et, 1)

        opt = (monthly_optical or {}).get(mo)
        is_bare = (
            (opt["ndvi"] < 0.22 and opt.get("scl", 5) == 5)
            if opt
            else (avg_et < 15.0 and cur_sm < 0.35)
        )
        if is_bare:
            bare_months.append(mo)
        erosion_risk[mo] = round(avg_p * kwfact * (slope_pct / 100.0) * (1.0 if is_bare else 0.25), 2)

    return {
        "latest_year": latest_yr,
        "soil_moisture_anomaly_z": sm_anomaly_z,
        "crop_water_deficit_mm": cwd_mm,
        "bare_soil_months": bare_months,
        "seasonal_erosion_risk": erosion_risk,
        "climate_trends_per_year": {
            "hot_days_above_35c_slope": theil_sen_slope(all_years, [year_hot[y] for y in all_years]),
            "frost_free_days_slope": theil_sen_slope(all_years, [year_frost_free[y] for y in all_years]),
        },
    }


def summarize_stage1_from_power_raw(
    raw_payload: dict[str, Any] | None,
    kwfact: float = 0.30,
) -> tuple[float, list[str]]:
    """Extract (smap_rootzone_anomaly_z, bare_field_month_names) from a raw NASA POWER response."""
    params = ((raw_payload or {}).get("properties") or {}).get("parameter") or {}
    if not params:
        return 0.0, []
    features = extract_stage1_features(params, kwfact=kwfact)
    anomalies = list(features["soil_moisture_anomaly_z"].values())
    # If single-year series (all monthly Z==0), compute worst monthly Z across the year when >1 month exists
    z_val = min(anomalies, default=0.0)
    if z_val == 0.0 and len(features["soil_moisture_anomaly_z"]) >= 2:
        sm = params.get("GWETROOT") or {}
        by_mo: dict[int, list[float]] = defaultdict(list)
        for day, val in sm.items():
            if val is not None and float(val) > -900:
                by_mo[int(day[4:6])].append(float(val))
        mo_means = [mean(v) for v in by_mo.values() if v]
        if len(mo_means) >= 2:
            mu, sd = mean(mo_means), pstdev(mo_means)
            if sd > 1e-6:
                z_val = round((min(mo_means) - mu) / sd, 2)
    month_names = [calendar.month_name[m] for m in features["bare_soil_months"]]
    return z_val, month_names
