import httpx


class UsdaCropsMarketClient:
    """CDL CropScape history, NASS QuickStats yields and AMS Market News prices."""

    CDL_URL = "https://nassgeodata.gmu.edu/axis2/services/CDLService/GetCDLStat"
    NASS_URL = "https://quickstats.nass.usda.gov/api/api_GET/"
    AMS_URL = "https://marsapi.ams.usda.gov/services/v1.2/reports"

    def __init__(self, client: httpx.AsyncClient | None = None) -> None:
        self._client = client

    async def fetch_point(self, lat: float, lon: float) -> dict:
        """Return county crop history and a price snapshot for a coordinate."""
        raise NotImplementedError(
            "USDA crops and market fetch_point is not implemented yet "
            f"for ({lat}, {lon}). Sources: {self.CDL_URL} | {self.NASS_URL} | {self.AMS_URL}"
        )
