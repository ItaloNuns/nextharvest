import httpx
import pytest
import respx

from app.connectors.census_location import CensusLocationClient, parse_census_payload
from tests.conftest import FCC_JSON


def test_parse_census_payload() -> None:
    parsed = parse_census_payload(FCC_JSON)
    assert parsed["state"] == "NV"
    assert parsed["county"] == "Churchill"


@pytest.mark.asyncio
async def test_lookup_parses_mocked_fcc() -> None:
    with respx.mock:
        respx.get(url__regex=r"https://geo\.fcc\.gov/.*").mock(
            return_value=httpx.Response(200, json=FCC_JSON)
        )
        result = await CensusLocationClient().lookup(39.475, -118.775)
    assert result["state"] == "NV"
    assert result["county"] == "Churchill"
