import httpx
import pytest
import respx

from app.connectors.usda_sda_soils import (
    UsdaSdaError,
    UsdaSdaSoilsClient,
    parse_sda_table,
    soil_profile_from_row,
)
from app.geo import to_wkt
from tests.conftest import DEMO_GEOMETRY, SDA_JSON, live_enabled


def test_parse_columnname_table() -> None:
    row = parse_sda_table(SDA_JSON)
    assert row is not None
    profile = soil_profile_from_row(row)
    assert profile.mapunit_name.startswith("Dia loam")
    assert profile.hydrologic_group == "B"
    assert profile.available_water_capacity_cm_cm == pytest.approx(0.16)
    assert profile.organic_matter_pct == 1.2


def test_parse_header_row_table() -> None:
    payload = {
        "Table": [
            ["muname", "hydgrp", "drainagecl", "awc_cm", "om_r", "kwfact"],
            ["Some loam", "C", "Poorly drained", 15, 2.0, 0.4],
        ]
    }
    row = parse_sda_table(payload)
    assert row is not None
    assert row["muname"] == "Some loam"


@pytest.mark.asyncio
async def test_fetch_polygon_parses_mocked_response(mock_nasa_usda) -> None:
    result = await UsdaSdaSoilsClient().fetch_polygon(to_wkt(DEMO_GEOMETRY))
    assert result["ok"] is True
    assert result["profile"]["mapunit_name"].startswith("Dia loam")


@pytest.mark.asyncio
async def test_fetch_polygon_empty_table_is_not_ok() -> None:
    with respx.mock:
        respx.post("https://SDMDataAccess.sc.egov.usda.gov/Tabular/post.rest").mock(
            return_value=httpx.Response(200, json={"Table": []})
        )
        result = await UsdaSdaSoilsClient().fetch_polygon("POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0))")
    assert result["ok"] is False
    assert result["profile"]["mapunit_name"] == ""


@pytest.mark.asyncio
async def test_fetch_polygon_raises_on_http_error() -> None:
    with respx.mock:
        respx.post("https://SDMDataAccess.sc.egov.usda.gov/Tabular/post.rest").mock(
            return_value=httpx.Response(503, text="down")
        )
        with pytest.raises(UsdaSdaError, match="HTTP 503"):
            await UsdaSdaSoilsClient().fetch_polygon("POLYGON ((0 0, 1 0, 1 1, 0 1, 0 0))")


@pytest.mark.live
@pytest.mark.asyncio
async def test_fetch_polygon_live_nevada() -> None:
    if not live_enabled():
        pytest.skip("Set NEXTHARVEST_LIVE=1 to call USDA SDA")
    result = await UsdaSdaSoilsClient().fetch_polygon(to_wkt(DEMO_GEOMETRY))
    assert result["ok"] is True
    assert result["profile"]["mapunit_name"]
