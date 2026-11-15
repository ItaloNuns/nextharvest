import httpx
import pytest
import respx

from app.connectors.usda_crops_market import (
    UsdaCropsMarketClient,
    UsdaCropsMarketError,
    nass_county_name,
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


def test_nass_county_name_strips_fcc_suffix() -> None:
    assert nass_county_name("Churchill County") == "CHURCHILL"
    assert nass_county_name("Orleans Parish") == "ORLEANS"
    assert nass_county_name("Churchill") == "CHURCHILL"


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
async def test_fetch_uses_nass_county_name_from_fcc_label() -> None:
    seen: list[str] = []

    def record_request(request: httpx.Request) -> httpx.Response:
        seen.append(request.url.params.get("county_name", ""))
        return httpx.Response(200, json=NASS_JSON)

    with respx.mock:
        respx.get(url__regex=r"https://quickstats\.nass\.usda\.gov/.*").mock(
            side_effect=record_request
        )
        await UsdaCropsMarketClient(api_key="test-key").fetch_county_yields(
            "NV", "Churchill County", year=2023
        )
    assert seen[0] == "CHURCHILL"


@pytest.mark.asyncio
async def test_fetch_retries_previous_year_after_http_error() -> None:
    years: list[str] = []

    def by_year(request: httpx.Request) -> httpx.Response:
        years.append(request.url.params.get("year", ""))
        year = request.url.params.get("year")
        if year == "2025":
            return httpx.Response(400, json={"error": ["bad query"]})
        return httpx.Response(200, json=NASS_JSON)

    with respx.mock:
        respx.get(url__regex=r"https://quickstats\.nass\.usda\.gov/.*").mock(side_effect=by_year)
        scores = await UsdaCropsMarketClient(api_key="test-key").fetch_county_yields(
            "NV", "Churchill County", year=2025
        )
    assert years == ["2025", "2024"]
    assert scores["corn"] == 90.0


@pytest.mark.asyncio
async def test_fetch_requires_key() -> None:
    with pytest.raises(UsdaCropsMarketError, match="NASS_API_KEY"):
        await UsdaCropsMarketClient(api_key="").fetch_county_yields("NV", "Churchill")
