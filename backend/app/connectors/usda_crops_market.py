from datetime import date
from typing import Any

import httpx

from app.config import get_settings

COMMODITY_TO_CROP: dict[tuple[str, str], str] = {
    ("CORN", ""): "corn",
    ("SOYBEANS", ""): "soybeans",
    ("WHEAT", ""): "winter_wheat",
    ("SORGHUM", ""): "sorghum",
    ("OATS", ""): "oats",
    ("SUNFLOWER", ""): "sunflower",
    ("CANOLA", ""): "canola",
    ("CHICKPEAS", ""): "chickpea",
    ("HAY", "ALFALFA"): "alfalfa",
    ("HAY", ""): "alfalfa",
}


class UsdaCropsMarketError(RuntimeError):
    """Raised when NASS QuickStats fails."""


def _parse_nass_value(raw: Any) -> float | None:
    if raw is None:
        return None
    text = str(raw).replace(",", "").strip()
    if text in {"", "(D)", "(Z)", "(NA)", "(X)"}:
        return None
    try:
        return float(text)
    except ValueError:
        return None


def _crop_code(commodity: str, class_desc: str) -> str | None:
    commodity_u = commodity.strip().upper()
    class_u = class_desc.strip().upper()
    if "ALFALFA" in class_u or "ALFALFA" in commodity_u:
        return "alfalfa"
    if (commodity_u, class_u) in COMMODITY_TO_CROP:
        return COMMODITY_TO_CROP[(commodity_u, class_u)]
    return COMMODITY_TO_CROP.get((commodity_u, ""))


def parse_nass_payload(payload: dict[str, Any]) -> dict[str, float]:
    """Pick the latest annual yield per catalog crop, then scale to 40–90 scores."""
    latest: dict[str, tuple[int, float]] = {}
    for row in payload.get("data") or []:
        if not isinstance(row, dict):
            continue
        code = _crop_code(str(row.get("commodity_desc") or ""), str(row.get("class_desc") or ""))
        value = _parse_nass_value(row.get("Value"))
        if not code or value is None:
            continue
        try:
            year = int(str(row.get("year") or "0"))
        except ValueError:
            year = 0
        previous = latest.get(code)
        if previous is None or year >= previous[0]:
            latest[code] = (year, value)
    yields = {code: pair[1] for code, pair in latest.items()}
    return yields_to_market_scores(yields)


def yields_to_market_scores(yields: dict[str, float]) -> dict[str, float]:
    if not yields:
        return {}
    values = list(yields.values())
    low, high = min(values), max(values)
    if high == low:
        return {code: 75.0 for code in yields}
    return {
        code: round(40.0 + 50.0 * (value - low) / (high - low), 2)
        for code, value in yields.items()
    }


class UsdaCropsMarketClient:
    """USDA NASS QuickStats county yields. AMS is not wired in this phase."""

    NASS_URL = "https://quickstats.nass.usda.gov/api/api_GET/"

    def __init__(self, client: httpx.AsyncClient | None = None, api_key: str | None = None) -> None:
        self._client = client
        self._api_key = get_settings().nass_api_key if api_key is None else api_key

    @property
    def enabled(self) -> bool:
        return bool(self._api_key)

    async def fetch_county_yields(self, state: str, county: str, year: int | None = None) -> dict[str, float]:
        if not self.enabled:
            raise UsdaCropsMarketError("NASS_API_KEY is not set")
        if not state or not county:
            return {}
        target_year = year or (date.today().year - 1)
        payload = await self._get(state, county, target_year)
        parsed = parse_nass_payload(payload)
        if parsed:
            return parsed
        payload = await self._get(state, county, target_year - 1)
        return parse_nass_payload(payload)

    async def _get(self, state: str, county: str, year: int) -> dict[str, Any]:
        params = {
            "key": self._api_key,
            "source_desc": "SURVEY",
            "sector_desc": "CROPS",
            "agg_level_desc": "COUNTY",
            "state_alpha": state.upper(),
            "county_name": county.upper(),
            "year": str(year),
            "statisticcat_desc": "YIELD",
            "freq_desc": "ANNUAL",
            "format": "JSON",
        }
        client = self._client or httpx.AsyncClient(timeout=30.0)
        close = self._client is None
        try:
            response = await client.get(self.NASS_URL, params=params)
        finally:
            if close:
                await client.aclose()
        if response.status_code != 200:
            raise UsdaCropsMarketError(
                f"NASS HTTP {response.status_code} for {county}, {state} ({year})"
            )
        try:
            return response.json()
        except ValueError as exc:
            raise UsdaCropsMarketError("NASS returned a non-JSON body") from exc
