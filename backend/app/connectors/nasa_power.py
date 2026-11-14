from datetime import date, timedelta
from typing import Any

import httpx

FILL_VALUE = -999.0
PARAMETERS = "PRECTOTCORR,T2M,T2M_MIN,T2M_MAX,GWETROOT,EVPTRNS"


class NasaPowerError(RuntimeError):
    """Raised when the NASA POWER request fails or cannot be parsed."""


def default_date_range(today: date | None = None) -> tuple[str, str]:
    end = today or date.today()
    start = end - timedelta(days=365)
    return start.strftime("%Y%m%d"), end.strftime("%Y%m%d")


def yyyymmdd_to_iso(value: str) -> str:
    return f"{value[:4]}-{value[4:6]}-{value[6:8]}"


def default_iso_date_range(today: date | None = None) -> tuple[str, str]:
    start, end = default_date_range(today)
    return yyyymmdd_to_iso(start), yyyymmdd_to_iso(end)


def _numeric_series(values: dict[str, Any], fill: float) -> list[float]:
    series: list[float] = []
    for raw in values.values():
        if raw is None:
            continue
        number = float(raw)
        if number <= fill + 1 or number <= -900:
            continue
        series.append(number)
    return series


def summarize_power_payload(payload: dict[str, Any]) -> dict[str, Any]:
    header = payload.get("header") or {}
    fill = float(header.get("fill_value", FILL_VALUE))
    parameters = (payload.get("properties") or {}).get("parameter") or {}
    precip = _numeric_series(parameters.get("PRECTOTCORR") or {}, fill)
    gwet = _numeric_series(parameters.get("GWETROOT") or {}, fill)
    t2m = _numeric_series(parameters.get("T2M") or {}, fill)
    et = _numeric_series(parameters.get("EVPTRNS") or {}, fill)
    return {
        "annual_precip_mm": round(sum(precip), 2),
        "annual_et_mm": round(sum(et), 2),
        "mean_gwetroot": round(sum(gwet) / len(gwet), 4) if gwet else None,
        "mean_t2m": round(sum(t2m) / len(t2m), 2) if t2m else None,
        "sample_days": len(precip),
    }


class NasaPowerClient:
    """Daily agroclimate at a point. https://power.larc.nasa.gov/"""

    BASE_URL = "https://power.larc.nasa.gov/api/temporal/daily/point"

    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client

    async def fetch_point(self, lat: float, lon: float, start: str, end: str) -> dict:
        """Return parsed NASA POWER climate for community=AG between start and end (YYYYMMDD)."""
        params = {
            "parameters": PARAMETERS,
            "community": "AG",
            "longitude": lon,
            "latitude": lat,
            "start": start,
            "end": end,
            "format": "JSON",
        }
        client = self._client or httpx.AsyncClient(timeout=30.0)
        close = self._client is None
        try:
            response = await client.get(self.BASE_URL, params=params)
        finally:
            if close:
                await client.aclose()
        if response.status_code != 200:
            raise NasaPowerError(
                f"NASA POWER HTTP {response.status_code} for ({lat}, {lon}) {start}..{end} "
                f"at {self.BASE_URL}"
            )
        try:
            payload = response.json()
        except ValueError as exc:
            raise NasaPowerError("NASA POWER returned a non-JSON body") from exc
        summary = summarize_power_payload(payload)
        return {"raw": payload, **summary}
