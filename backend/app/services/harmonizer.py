import asyncio
import logging
from dataclasses import dataclass, field

import httpx

from app.connectors.nasa_power import NasaPowerClient, default_date_range
from app.connectors.usda_sda_soils import UsdaSdaSoilsClient
from app.geo import centroid, to_wkt
from app.schemas.rotation_models import (
    FieldAnalyzeRequest,
    HarmonizedSummary,
    SoilProfile,
    empty_summary,
)

logger = logging.getLogger("nextharvest.harmonizer")


@dataclass
class HarmonizerResult:
    summary: HarmonizedSummary
    climate_ok: bool
    soil_ok: bool
    failures: list[str] = field(default_factory=list)
    lat: float = 0.0
    lon: float = 0.0

    @property
    def complete(self) -> bool:
        return self.climate_ok and self.soil_ok


class GeoHarmonizerService:
    """Fuse climate and soil inputs onto the field (MVP: centroid + polygon WKT)."""

    def __init__(self, http: httpx.AsyncClient | None = None) -> None:
        self._power = NasaPowerClient(http)
        self._soils = UsdaSdaSoilsClient(http)

    async def summarize(self, field: FieldAnalyzeRequest) -> HarmonizerResult:
        lat, lon = centroid(field.geometry)
        wkt = to_wkt(field.geometry)
        climate_task = asyncio.create_task(self._climate(lat, lon))
        soil_task = asyncio.create_task(self._soil(wkt))
        climate_ok, climate, climate_error = await climate_task
        soil_ok, soil, soil_error = await soil_task

        failures: list[str] = []
        if climate_error:
            failures.append(climate_error)
        if soil_error:
            failures.append(soil_error)

        precip = float(climate.get("annual_precip_mm") or 0)
        et_demand = 0.0
        summary = HarmonizedSummary(
            annual_precip_mm=precip,
            annual_et_demand_mm=et_demand,
            water_balance_deficit_mm=round(precip - et_demand, 2),
            smap_rootzone_anomaly_z=0,
            bare_field_months=[],
            soil_profile=soil,
        )
        return HarmonizerResult(
            summary=summary,
            climate_ok=climate_ok,
            soil_ok=soil_ok,
            failures=failures,
            lat=lat,
            lon=lon,
        )

    async def _climate(self, lat: float, lon: float) -> tuple[bool, dict, str | None]:
        start, end = default_date_range()
        try:
            data = await self._power.fetch_point(lat, lon, start, end)
            return True, data, None
        except Exception as exc:
            logger.warning("NASA POWER failed: %s", exc)
            return False, {}, f"NASA POWER: {exc}"

    async def _soil(self, wkt: str) -> tuple[bool, SoilProfile, str | None]:
        empty = empty_summary().soil_profile
        try:
            data = await self._soils.fetch_polygon(wkt)
        except Exception as exc:
            logger.warning("USDA SDA failed: %s", exc)
            return False, empty, f"USDA Soil Data Access: {exc}"
        profile = SoilProfile.model_validate(data.get("profile") or empty.model_dump())
        if not data.get("ok"):
            return False, profile, "USDA Soil Data Access: no map unit for this polygon (SSURGO is CONUS-only)"
        return True, profile, None
