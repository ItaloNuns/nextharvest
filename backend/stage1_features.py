from collections import defaultdict
import os
from pathlib import Path
from statistics import mean, median, pstdev
import httpx


def _load_dotenv() -> None:
    env_file = Path(__file__).with_name(".env")
    if env_file.exists():
        for line in env_file.read_text(encoding="utf-8").splitlines():
            if "=" in line and not line.strip().startswith("#"):
                k, v = line.split("=", 1)
                if v.strip():
                    os.environ.setdefault(k.strip(), v.strip())


_load_dotenv()

POWER_URL = "https://power.larc.nasa.gov/api/temporal/daily/point"
OPENET_URL = "https://openet-api.org/raster/timeseries/point"


def theil_sen_slope(years: list[int], values: list[float]) -> float:
    slopes = [
        (values[j] - values[i]) / (years[j] - years[i])
        for i in range(len(years))
        for j in range(i + 1, len(years))
        if years[j] != years[i]
    ]
    return round(median(slopes), 4) if slopes else 0.0


def fetch_nasa_power_daily(lat: float, lon: float, start_year: int = 2005, end_year: int = 2025) -> dict:
    if not (-90 <= lat <= 90 and -180 <= lon <= 180) or start_year > end_year:
        raise ValueError("Invalid coordinates or year range")
    params = {
        "parameters": "T2M_MAX,T2M_MIN,PRECTOTCORR,EVPTRNS,GWETROOT",
        "community": "AG",
        "latitude": lat,
        "longitude": lon,
        "start": f"{start_year}0101",
        "end": f"{end_year}1231",
        "format": "JSON",
    }
    r = httpx.get(POWER_URL, params=params, timeout=30)
    r.raise_for_status()
    return r.json()["properties"]["parameter"]


def fetch_openet_et(
    lat: float,
    lon: float,
    start_year: int = 2021,
    end_year: int = 2025,
    api_key: str | None = None,
) -> dict[int, float]:
    """Fetch field-scale 30m monthly Ensemble ET (mm) from OpenET API v2.0."""
    key = api_key or os.getenv("OPENET_API_KEY")
    if not key:
        return {}
    payload = {
        "date_range": [f"{start_year}-01-01", f"{end_year}-12-31"],
        "interval": "monthly",
        "geometry": [lon, lat],
        "model": "Ensemble",
        "variable": "ET",
        "reference_et": "gridMET",
        "units": "mm",
        "file_format": "JSON",
    }
    r = httpx.post(OPENET_URL, json=payload, headers={"Authorization": key}, timeout=30)
    r.raise_for_status()
    by_month = defaultdict(list)
    for row in r.json():
        if row.get("et") is not None:
            mo = int(str(row["time"])[5:7])
            by_month[mo].append(float(row["et"]))
    return {mo: round(mean(vals), 2) for mo, vals in by_month.items() if vals}


def extract_stage1_features(
    power_params: dict[str, dict[str, float]],
    monthly_optical: dict[int, dict[str, float]] | None = None,
    openet_monthly_mm: dict[int, float] | None = None,
    kwfact: float = 0.30,
    slope_pct: float = 2.0,
) -> dict:
    """Compute Stage 1 biophysical features from daily NASA POWER series and optional monthly NDVI/SCL."""
    tmax = power_params["T2M_MAX"]
    tmin = power_params["T2M_MIN"]
    precip = power_params["PRECTOTCORR"]
    et = power_params.get("EVPTRNS", {})
    sm = power_params["GWETROOT"]

    month_sm = defaultdict(lambda: defaultdict(list))
    month_p = defaultdict(lambda: defaultdict(float))
    month_et = defaultdict(lambda: defaultdict(float))
    year_hot = defaultdict(int)
    year_frost_free = defaultdict(int)

    for day, p_val in precip.items():
        if p_val < -900 or sm.get(day, -999) < -900:
            continue
        yr, mo = int(day[:4]), int(day[4:6])
        month_sm[mo][yr].append(sm[day])
        month_p[mo][yr] += p_val
        # shortcut: uses Hargreaves-like 0.15*max(0, tmax) daily ET fallback if EVPTRNS is missing, upgrade when OpenET/ECOSTRESS connector is wired
        et_val = et.get(day, -999)
        month_et[mo][yr] += et_val if et_val > -900 else max(0.0, tmax.get(day, 0.0) * 0.15)
        if tmax.get(day, -999) > 35.0:
            year_hot[yr] += 1
        if tmin.get(day, -999) >= 0.0:
            year_frost_free[yr] += 1

    latest_yr = max(year_frost_free)
    sm_anomaly_z = {}
    cwd_mm = {}
    bare_months = []
    erosion_risk = {}

    for mo in range(1, 13):
        yr_means = {y: mean(vals) for y, vals in month_sm[mo].items() if vals}
        if not yr_means:
            continue
        mu = mean(yr_means.values())
        sd = pstdev(yr_means.values()) or 1e-6
        cur_sm = yr_means.get(latest_yr, mu)
        sm_anomaly_z[mo] = round((cur_sm - mu) / sd, 2)

        avg_p = mean(month_p[mo].values())
        avg_et = (openet_monthly_mm or {}).get(mo, mean(month_et[mo].values()))
        cwd_mm[mo] = round(avg_p - avg_et, 1)

        opt = (monthly_optical or {}).get(mo)
        # shortcut: infers bare soil when NDVI/SCL is omitted from low transpiration (<15mm) and dry surface, upgrade when Sentinel-2/Landsat series is always present
        is_bare = (
            (opt["ndvi"] < 0.22 and opt.get("scl", 5) == 5)
            if opt
            else (avg_et < 15.0 and cur_sm < 0.35)
        )
        if is_bare:
            bare_months.append(mo)
        erosion_risk[mo] = round(avg_p * kwfact * (slope_pct / 100.0) * (1.0 if is_bare else 0.25), 2)

    years = sorted(year_frost_free)
    return {
        "latest_year": latest_yr,
        "soil_moisture_anomaly_z": sm_anomaly_z,
        "crop_water_deficit_mm": cwd_mm,
        "bare_soil_months": bare_months,
        "seasonal_erosion_risk": erosion_risk,
        "climate_trends_per_year": {
            "hot_days_above_35c_slope": theil_sen_slope(years, [year_hot[y] for y in years]),
            "frost_free_days_slope": theil_sen_slope(years, [year_frost_free[y] for y in years]),
        },
    }
