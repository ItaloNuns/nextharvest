import httpx


class OpenEtClient:
    """Field-scale evapotranspiration. https://openet-api.org/"""

    BASE_URL = "https://openet-api.org/"

    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client

    async def fetch_polygon(self, geojson: dict, start: str, end: str) -> dict:
        """Return an ET time series for a GeoJSON polygon (POST /raster/timeseries/polygon)."""
        raise NotImplementedError(
            "OpenET fetch_polygon is not implemented yet "
            f"for {start}..{end} ({geojson.get('type', 'geometry')}). Source: {self.BASE_URL}"
        )
