from typing import Any

import httpx

from app.config import get_settings
from app.geo import centroid, flatten_lonlat_ring


class OpenEtError(RuntimeError):
    """Raised when the OpenET request fails or cannot be parsed."""


def summarize_openet_payload(payload: Any) -> dict[str, Any]:
    """Sum monthly ET values from a list of row dicts or a keyed object."""
    rows: list[Any]
    if isinstance(payload, list):
        rows = payload
    elif isinstance(payload, dict):
        rows = payload.get("data") or payload.get("timeseries") or payload.get("results") or []
        if not rows and any(
            key.lower() not in {"status", "message", "error"} and _as_float(value) is not None
            for key, value in payload.items()
        ):
            rows = [{"et": value} for key, value in payload.items() if _as_float(value) is not None]
    else:
        rows = []

    total = 0.0
    samples = 0
    skip = {"time", "date", "month", "year", "datetime"}
    for row in rows:
        if not isinstance(row, dict):
            number = _as_float(row)
            if number is not None:
                total += number
                samples += 1
            continue
        for key, value in row.items():
            if str(key).lower() in skip:
                continue
            number = _as_float(value)
            if number is None:
                continue
            total += number
            samples += 1
            break
    return {"ok": samples > 0, "annual_et_mm": round(total, 2), "sample_months": samples}


def _as_float(value: Any) -> float | None:
    if value is None or isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    if number <= -900:
        return None
    return number


class OpenEtClient:
    """Field-scale evapotranspiration. https://openet-api.org/"""

    BASE_URL = "https://openet-api.org/"
    POLYGON_URL = "https://openet-api.org/raster/timeseries/polygon"
    POINT_URL = "https://openet-api.org/raster/timeseries/point"

    def __init__(self, client: httpx.AsyncClient | None = None, api_key: str | None = None) -> None:
        self._client = client
        self._api_key = get_settings().openet_api_key if api_key is None else api_key

    @property
    def enabled(self) -> bool:
        return bool(self._api_key)

    async def fetch_polygon(self, geojson: dict, start: str, end: str) -> dict:
        """Return annual ET (mm) for a GeoJSON polygon; falls back to the centroid point."""
        if not self.enabled:
            raise OpenEtError("OPENET_API_KEY is not set")
        try:
            payload = await self._post(
                self.POLYGON_URL,
                geometry=flatten_lonlat_ring(geojson),
                reducer="mean",
                start=start,
                end=end,
            )
            parsed = summarize_openet_payload(payload)
            if parsed["ok"]:
                return parsed
        except OpenEtError:
            pass
        lat, lon = centroid(geojson)
        return await self.fetch_point(lat, lon, start, end)

    async def fetch_point(self, lat: float, lon: float, start: str, end: str) -> dict:
        if not self.enabled:
            raise OpenEtError("OPENET_API_KEY is not set")
        payload = await self._post(
            self.POINT_URL,
            geometry=[lon, lat],
            reducer=None,
            start=start,
            end=end,
        )
        parsed = summarize_openet_payload(payload)
        if not parsed["ok"]:
            raise OpenEtError(f"OpenET returned no ET samples for ({lat}, {lon}) {start}..{end}")
        return parsed

    async def _post(
        self,
        url: str,
        *,
        geometry: list[float],
        reducer: str | None,
        start: str,
        end: str,
    ) -> Any:
        body: dict[str, Any] = {
            "date_range": [start, end],
            "interval": "monthly",
            "geometry": geometry,
            "model": "Ensemble",
            "variable": "ET",
            "reference_et": "gridMET",
            "units": "mm",
            "file_format": "JSON",
        }
        if reducer:
            body["reducer"] = reducer
        headers = {"Authorization": self._api_key, "Content-Type": "application/json"}
        client = self._client or httpx.AsyncClient(timeout=60.0)
        close = self._client is None
        try:
            response = await client.post(url, json=body, headers=headers)
        finally:
            if close:
                await client.aclose()
        if response.status_code != 200:
            raise OpenEtError(f"OpenET HTTP {response.status_code} at {url}")
        try:
            return response.json()
        except ValueError as exc:
            raise OpenEtError("OpenET returned a non-JSON body") from exc
