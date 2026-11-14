from typing import Any

import httpx


class CensusLocationError(RuntimeError):
    """Raised when the FCC census lookup fails."""


class CensusLocationClient:
    """County and state from a WGS84 point (no API key)."""

    BASE_URL = "https://geo.fcc.gov/api/census/area"

    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client

    async def lookup(self, lat: float, lon: float) -> dict[str, str]:
        params = {"lat": lat, "lon": lon, "censusYear": "2020", "format": "json"}
        client = self._client or httpx.AsyncClient(timeout=15.0)
        close = self._client is None
        try:
            response = await client.get(self.BASE_URL, params=params)
        finally:
            if close:
                await client.aclose()
        if response.status_code != 200:
            raise CensusLocationError(f"FCC census HTTP {response.status_code} for ({lat}, {lon})")
        try:
            payload = response.json()
        except ValueError as exc:
            raise CensusLocationError("FCC census returned a non-JSON body") from exc
        parsed = parse_census_payload(payload)
        if not parsed["state"] and not parsed["county"]:
            raise CensusLocationError(f"FCC census found no county for ({lat}, {lon})")
        return parsed


def parse_census_payload(payload: dict[str, Any]) -> dict[str, str]:
    results = payload.get("results") or []
    row = results[0] if results else {}
    return {
        "state": str(row.get("state_code") or "").strip(),
        "county": str(row.get("county_name") or "").strip(),
        "state_fips": str(row.get("state_fips") or "").strip(),
        "county_fips": str(row.get("county_fips") or "").strip(),
    }
