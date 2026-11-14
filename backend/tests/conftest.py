import os

import httpx
import pytest
import respx

DEMO_GEOMETRY = {
    "type": "Polygon",
    "coordinates": [
        [
            [-118.78, 39.47],
            [-118.77, 39.47],
            [-118.77, 39.48],
            [-118.78, 39.48],
            [-118.78, 39.47],
        ]
    ],
}

ANALYZE_BODY = {
    "name": "Alfafa Nevada",
    "current_crop": "Alfafa",
    "geometry": DEMO_GEOMETRY,
}

POWER_JSON = {
    "header": {"fill_value": -999.0},
    "properties": {
        "parameter": {
            "PRECTOTCORR": {"20250101": 10.0, "20250102": 5.0, "20250103": -999.0},
            "GWETROOT": {"20250101": 0.4, "20250102": 0.6},
            "T2M": {"20250101": 12.0, "20250102": 14.0},
        }
    },
}

SDA_JSON = {
    "Table": [
        {
            "muname": "Dia loam, 0 to 2 percent slopes",
            "hydgrp": "B",
            "drainagecl": "Well drained",
            "awc_cm": 24,
            "om_r": 1.2,
            "kwfact": 0.32,
        }
    ]
}

SOIL_PROFILE = {
    "mapunit_name": "Dia loam, 0 to 2 percent slopes",
    "organic_matter_pct": 1.2,
    "available_water_capacity_cm_cm": 0.16,
    "drainage_class": "Well drained",
    "hydrologic_group": "B",
    "erosion_k_factor": 0.32,
}


def live_enabled() -> bool:
    return os.getenv("NEXTHARVEST_LIVE") == "1"


@pytest.fixture
def mock_nasa_usda():
    with respx.mock(assert_all_called=False) as router:
        router.get(url__regex=r"https://power\.larc\.nasa\.gov/.*").mock(
            return_value=httpx.Response(200, json=POWER_JSON)
        )
        router.post("https://SDMDataAccess.sc.egov.usda.gov/Tabular/post.rest").mock(
            return_value=httpx.Response(200, json=SDA_JSON)
        )
        yield router
