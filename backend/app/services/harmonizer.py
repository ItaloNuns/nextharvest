import asyncio
import logging
from dataclasses import dataclass, field

import httpx

from app.connectors.nasa_power import NasaPowerClient, default_date_range, default_iso_date_range
from app.connectors.openet_client import OpenEtClient
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
    et_ok: bool = False
    et_source: str = "none"
    failures: list[str] = field(default_factory=list)
    lat: float = 0.0
    lon: float = 0.0

    @property
    def complete(self) -> bool:
        return self.climate_ok and self.soil_ok


class GeoHarmonizerService:
    """Fuse climate, ET and soil inputs onto the field (centroid + polygon)."""

    def __init__(self, http: httpx.AsyncClient | None = None) -> None:
        self._http = http
        self._power = NasaPowerClient(http)
        self._soils = UsdaSdaSoilsClient(http)
        self._openet = OpenEtClient(http)

    async def summarize(self, field: FieldAnalyzeRequest) -> HarmonizerResult:
        lat, lon = centroid(field.geometry)
        wkt = to_wkt(field.geometry)
        start_iso, end_iso = default_iso_date_range()
        climate_task = asyncio.create_task(self._climate(lat, lon))
        soil_task = asyncio.create_task(self._soil(wkt))
        et_task = asyncio.create_task(self._et(field.geometry, start_iso, end_iso))
        climate_ok, climate, climate_error = await climate_task
        soil_ok, soil, soil_error = await soil_task
        et_ok, openet_mm, et_error = await et_task

        failures: list[str] = []
        if climate_error:
            failures.append(climate_error)
        if soil_error:
            failures.append(soil_error)
        if et_error:
            failures.append(et_error)

        precip = float(climate.get("annual_precip_mm") or 0)
        power_et = float(climate.get("annual_et_mm") or 0)
        if et_ok and openet_mm > 0:
            et_demand = openet_mm
            et_source = "openet"
        elif power_et > 0:
            et_demand = power_et
            et_source = "power"
        else:
            et_demand = 0.0
            et_source = "none"

        summary = HarmonizedSummary(
            annual_precip_mm=precip,
            annual_et_demand_mm=round(et_demand, 2),
            water_balance_deficit_mm=round(precip - et_demand, 2),
            smap_rootzone_anomaly_z=0,
            bare_field_months=[],
            soil_profile=soil,
        )
        return HarmonizerResult(
            summary=summary,
            climate_ok=climate_ok,
            soil_ok=soil_ok,
            et_ok=et_source == "openet",
            et_source=et_source,
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

    async def _et(self, geometry: dict, start: str, end: str) -> tuple[bool, float, str | None]:
        if not self._openet.enabled:
            return False, 0.0, None
        try:
            data = await self._openet.fetch_polygon(geometry, start, end)
            return True, float(data.get("annual_et_mm") or 0), None
        except Exception as exc:
            logger.warning("OpenET failed: %s", exc)
            return False, 0.0, f"OpenET: {exc}"
