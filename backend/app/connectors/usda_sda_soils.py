from typing import Any

import httpx

from app.schemas.rotation_models import SoilProfile, empty_summary


class UsdaSdaError(RuntimeError):
    """Raised when Soil Data Access cannot be reached or parsed."""


def _escape_wkt(wkt: str) -> str:
    return wkt.replace("'", "''")


def build_sda_query(wkt: str) -> str:
    safe_wkt = _escape_wkt(wkt)
    return f"""
SELECT TOP 1
  mu.muname,
  att.hydgrpdcd AS hydgrp,
  att.drclassdcd AS drainagecl,
  att.aws0150wta AS awc_cm,
  (
    SELECT TOP 1 ch.om_r
    FROM component c
    INNER JOIN chorizon ch ON ch.cokey = c.cokey
    WHERE c.mukey = mu.mukey AND c.majcompflag = 'Yes'
    ORDER BY ch.hzdept_r
  ) AS om_r,
  (
    SELECT TOP 1 ch.kwfact
    FROM component c
    INNER JOIN chorizon ch ON ch.cokey = c.cokey
    WHERE c.mukey = mu.mukey AND c.majcompflag = 'Yes'
    ORDER BY ch.hzdept_r
  ) AS kwfact
FROM SDA_Get_Mukey_from_intersection_with_WktWgs84('{safe_wkt}') AS inter
INNER JOIN mapunit mu ON mu.mukey = inter.mukey
INNER JOIN muaggatt att ON att.mukey = mu.mukey
""".strip()


def _as_float(value: Any, default: float = 0.0) -> float:
    if value is None or value == "":
        return default
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _as_str(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def parse_sda_table(payload: Any) -> dict[str, Any] | None:
    if not isinstance(payload, dict):
        return None
    table = payload.get("Table")
    if not isinstance(table, list) or not table:
        return None
    first = table[0]
    if isinstance(first, dict):
        return first
    if isinstance(first, list) and len(table) >= 2 and all(isinstance(c, str) for c in first):
        headers = [str(col) for col in first]
        values = table[1]
        if not isinstance(values, list):
            return None
        return dict(zip(headers, values, strict=False))
    return None


def soil_profile_from_row(row: dict[str, Any]) -> SoilProfile:
    awc_cm = _as_float(row.get("awc_cm") or row.get("aws0150wta"))
    awc = round(awc_cm / 150.0, 4) if awc_cm else 0.0
    return SoilProfile(
        mapunit_name=_as_str(row.get("muname") or row.get("mapunit_name")),
        organic_matter_pct=round(_as_float(row.get("om_r")), 2),
        available_water_capacity_cm_cm=awc,
        drainage_class=_as_str(row.get("drainagecl") or row.get("drclassdcd")),
        hydrologic_group=_as_str(row.get("hydgrp") or row.get("hydgrpdcd")),
        erosion_k_factor=round(_as_float(row.get("kwfact") or row.get("kffact")), 2),
    )


class UsdaSdaSoilsClient:
    """SSURGO properties for a field polygon via Soil Data Access."""

    BASE_URL = "https://SDMDataAccess.sc.egov.usda.gov/Tabular/post.rest"

    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client

    async def fetch_polygon(self, wkt: str) -> dict:
        """Return texture, organic matter, drainage and available water for a WKT polygon."""
        query = build_sda_query(wkt)
        client = self._client or httpx.AsyncClient(timeout=30.0)
        close = self._client is None
        try:
            response = await client.post(
                self.BASE_URL,
                data={"query": query, "format": "JSON+COLUMNNAME"},
            )
        finally:
            if close:
                await client.aclose()
        if response.status_code != 200:
            raise UsdaSdaError(
                f"USDA SDA HTTP {response.status_code} for polygon. Source: {self.BASE_URL}"
            )
        try:
            payload = response.json()
        except ValueError as exc:
            raise UsdaSdaError("USDA SDA returned a non-JSON body") from exc
        row = parse_sda_table(payload)
        if not row or not _as_str(row.get("muname") or row.get("mapunit_name")):
            empty = empty_summary().soil_profile
            return {"ok": False, "profile": empty.model_dump(), "raw": payload}
        profile = soil_profile_from_row(row)
        return {"ok": True, "profile": profile.model_dump(), "raw": payload}
