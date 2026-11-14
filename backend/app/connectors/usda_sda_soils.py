import httpx


class UsdaSdaSoilsClient:
    """SSURGO properties for a field polygon via Soil Data Access."""

    BASE_URL = "https://SDMDataAccess.sc.egov.usda.gov/Tabular/post.rest"

    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client

    async def fetch_polygon(self, wkt: str) -> dict:
        """Return texture, organic matter, pH, drainage and available water for a WKT polygon."""
        raise NotImplementedError(
            "USDA Soil Data Access fetch_polygon is not implemented yet "
            f"for {wkt}. Source: {self.BASE_URL}"
        )
