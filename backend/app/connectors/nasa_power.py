import httpx


class NasaPowerClient:
    """Daily agroclimate at a point. https://power.larc.nasa.gov/"""

    BASE_URL = "https://power.larc.nasa.gov/api/temporal/daily/point"

    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client

    async def fetch_point(self, lat: float, lon: float, start: str, end: str) -> dict:
        """Return NASA POWER JSON for community=AG between start and end (YYYYMMDD)."""
        raise NotImplementedError(
            "NASA POWER fetch_point is not implemented yet "
            f"for ({lat}, {lon}) {start}..{end}. Source: {self.BASE_URL}"
        )
