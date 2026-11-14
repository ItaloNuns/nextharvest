import logging

import httpx

from app.connectors.census_location import CensusLocationClient
from app.connectors.usda_crops_market import UsdaCropsMarketClient
from app.schemas.rotation_models import Location

logger = logging.getLogger("nextharvest.market")


async def lookup_location(http: httpx.AsyncClient | None, lat: float, lon: float) -> Location:
    location = Location(lat=round(lat, 6), lon=round(lon, 6), state="", county="")
    try:
        geo = await CensusLocationClient(http).lookup(lat, lon)
        location.state = geo.get("state") or ""
        location.county = geo.get("county") or ""
    except Exception as exc:
        logger.warning("Census location failed: %s", exc)
    return location


async def lookup_nass_scores(
    http: httpx.AsyncClient | None,
    state: str,
    county: str,
) -> dict[str, float]:
    client = UsdaCropsMarketClient(http)
    if not client.enabled or not state or not county:
        return {}
    try:
        return await client.fetch_county_yields(state, county)
    except Exception as exc:
        logger.warning("NASS failed: %s", exc)
        return {}
