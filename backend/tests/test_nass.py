import httpx
import pytest
import respx

from app.connectors.usda_crops_market import (
    UsdaCropsMarketClient,
    UsdaCropsMarketError,
    parse_nass_payload,
    yields_to_market_scores,
)
from tests.conftest import NASS_JSON


def test_parse_nass_maps_commodities_and_scales_scores() -> None:
    scores = parse_nass_payload(NASS_JSON)
    assert "corn" in scores
    assert "alfalfa" in scores
    assert "sorghum" in scores
    assert scores["corn"] == 90.0
    assert scores["alfalfa"] == 40.0


def test_equal_yields_share_mid_score() -> None:
    assert yields_to_market_scores({"corn": 10.0, "sorghum": 10.0}) == {
        "corn": 75.0,
        "sorghum": 75.0,
    }


@pytest.mark.asyncio
async def test_fetch_county_yields_mocked() -> None:
    with respx.mock:
        respx.get(url__regex=r"https://quickstats\.nass\.usda\.gov/.*").mock(
            return_value=httpx.Response(200, json=NASS_JSON)
        )
        scores = await UsdaCropsMarketClient(api_key="test-key").fetch_county_yields("NV", "Churchill", year=2023)
    assert scores["corn"] == 90.0


@pytest.mark.asyncio
async def test_fetch_requires_key() -> None:
    with pytest.raises(UsdaCropsMarketError, match="NASS_API_KEY"):
        await UsdaCropsMarketClient(api_key="").fetch_county_yields("NV", "Churchill")
