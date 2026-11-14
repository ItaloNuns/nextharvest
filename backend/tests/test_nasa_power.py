import httpx
import pytest
import respx

from app.connectors.nasa_power import NasaPowerClient, NasaPowerError, summarize_power_payload
from tests.conftest import POWER_JSON, live_enabled


def test_summarize_power_payload_sums_precip_and_skips_fill() -> None:
    summary = summarize_power_payload(POWER_JSON)
    assert summary["annual_precip_mm"] == 15.0
    assert summary["mean_gwetroot"] == 0.5
    assert summary["mean_t2m"] == 13.0
    assert summary["sample_days"] == 2


@pytest.mark.asyncio
async def test_fetch_point_parses_mocked_response(mock_nasa_usda) -> None:
    result = await NasaPowerClient().fetch_point(39.475, -118.775, "20250101", "20251231")
    assert result["annual_precip_mm"] == 15.0
    assert result["sample_days"] == 2


@pytest.mark.asyncio
async def test_fetch_point_raises_on_http_error() -> None:
    with respx.mock:
        respx.get(url__regex=r"https://power\.larc\.nasa\.gov/.*").mock(
            return_value=httpx.Response(500, text="nope")
        )
        with pytest.raises(NasaPowerError, match="HTTP 500"):
            await NasaPowerClient().fetch_point(39.475, -118.775, "20250101", "20250102")


@pytest.mark.live
@pytest.mark.asyncio
async def test_fetch_point_live_nevada() -> None:
    if not live_enabled():
        pytest.skip("Set NEXTHARVEST_LIVE=1 to call NASA POWER")
    result = await NasaPowerClient().fetch_point(39.475, -118.775, "20240101", "20241231")
    assert result["annual_precip_mm"] > 0
    assert result["sample_days"] > 30
