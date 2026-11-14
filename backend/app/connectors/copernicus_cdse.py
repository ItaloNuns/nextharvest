import httpx


class CopernicusCdseClient:
    """Sentinel-2 field statistics (NDVI, NDRE and bare soil) without downloading rasters."""

    BASE_URL = "https://catalogue.dataspace.copernicus.eu/stac"

    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client

    async def fetch_polygon(self, geojson: dict, start: str, end: str) -> dict:
        """Return NDVI, NDRE and bare-soil fraction for a field polygon."""
        raise NotImplementedError(
            "Copernicus CDSE fetch_polygon is not implemented yet "
            f"for {start}..{end} ({geojson.get('type', 'geometry')}). Source: {self.BASE_URL}"
        )
