import httpx


class NasaAppeearsClient:
    """Point time series for SMAP, MODIS, VIIRS, ECOSTRESS and SRTM."""

    BASE_URL = "https://appeears.earthdatacloud.nasa.gov/api/"

    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client

    async def fetch_point(self, lat: float, lon: float, product: str, layer: str) -> dict:
        """Submit and read an AppEEARS point task for one product layer."""
        raise NotImplementedError(
            "NASA AppEEARS fetch_point is not implemented yet "
            f"for ({lat}, {lon}) {product}/{layer}. Source: {self.BASE_URL}"
        )
