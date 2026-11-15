import httpx
import pytest
import respx

from app.connectors.openet_client import OpenEtClient, OpenEtError, summarize_openet_payload
from app.config import get_settings
from tests.conftest import DEMO_GEOMETRY, OPENET_JSON, live_enabled


class _TimeoutRecorder:
    def __init__(self) -> None:
        self.timeouts: list[object] = []

    async def post(self, url, **kwargs):
        self.timeouts.append(kwargs.get("timeout"))
        return httpx.Response(200, json=OPENET_JSON)


def test_summarize_openet_sums_monthly_et() -> None:
    parsed = summarize_openet_payload(OPENET_JSON)
    assert parsed["ok"] is True
    assert parsed["annual_et_mm"] == 200.0
    assert parsed["sample_months"] == 2


def test_summarize_openet_empty_is_not_ok() -> None:
    assert summarize_openet_payload([])["ok"] is False


@pytest.mark.asyncio
async def test_fetch_polygon_parses_mocked_response() -> None:
    with respx.mock:
        respx.post("https://openet-api.org/raster/timeseries/polygon").mock(
            return_value=httpx.Response(200, json=OPENET_JSON)
        )
        result = await OpenEtClient(api_key="test-key").fetch_polygon(
            DEMO_GEOMETRY, "2025-01-01", "2025-12-31"
        )
    assert result["annual_et_mm"] == 200.0


@pytest.mark.asyncio
async def test_fetch_polygon_retries_503_then_succeeds() -> None:
    with respx.mock:
        route = respx.post("https://openet-api.org/raster/timeseries/polygon").mock(
            side_effect=[
                httpx.Response(503, text="busy"),
                httpx.Response(200, json=OPENET_JSON),
            ]
        )
        result = await OpenEtClient(api_key="test-key").fetch_polygon(
            DEMO_GEOMETRY, "2025-01-01", "2025-12-31"
        )
    assert result["annual_et_mm"] == 200.0
    assert route.call_count == 2


@pytest.mark.asyncio
async def test_openet_post_uses_60s_timeout() -> None:
    recorder = _TimeoutRecorder()
    result = await OpenEtClient(recorder, api_key="test-key").fetch_point(
        39.47, -118.77, "2025-01-01", "2025-12-31"
    )
    assert result["annual_et_mm"] == 200.0
    assert recorder.timeouts == [60.0]


@pytest.mark.asyncio
async def test_fetch_polygon_falls_back_to_point() -> None:
    with respx.mock:
        respx.post("https://openet-api.org/raster/timeseries/polygon").mock(
            return_value=httpx.Response(500, text="nope")
        )
        respx.post("https://openet-api.org/raster/timeseries/point").mock(
            return_value=httpx.Response(200, json=OPENET_JSON)
        )
        result = await OpenEtClient(api_key="test-key").fetch_polygon(
            DEMO_GEOMETRY, "2025-01-01", "2025-12-31"
        )
    assert result["annual_et_mm"] == 200.0


@pytest.mark.asyncio
async def test_fetch_polygon_requires_key() -> None:
    with pytest.raises(OpenEtError, match="OPENET_API_KEY"):
        await OpenEtClient(api_key="").fetch_polygon(DEMO_GEOMETRY, "2025-01-01", "2025-12-31")


@pytest.mark.live
@pytest.mark.asyncio
async def test_fetch_polygon_live_nevada() -> None:
    if not live_enabled() or not get_settings().openet_api_key:
        pytest.skip("Set NEXTHARVEST_LIVE=1 and OPENET_API_KEY to call OpenET")
    result = await OpenEtClient().fetch_polygon(DEMO_GEOMETRY, "2024-01-01", "2024-12-31")
    assert result["annual_et_mm"] > 0
    assert result["sample_months"] > 0
