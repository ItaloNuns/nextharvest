import os
import uuid

import httpx
import pytest
import respx

from app.schemas.rotation_models import DEMO_PRIORITIES_JSON

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

RECOMMEND_PRIORITIES = DEMO_PRIORITIES_JSON

POWER_JSON = {
    "header": {"fill_value": -999.0},
    "properties": {
        "parameter": {
            "PRECTOTCORR": {"20250101": 10.0, "20250102": 5.0, "20250103": -999.0},
            "GWETROOT": {"20250101": 0.4, "20250102": 0.6},
            "T2M": {"20250101": 12.0, "20250102": 14.0},
            "EVPTRNS": {"20250101": 20.0, "20250102": 10.0, "20250103": -999.0},
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

OPENET_JSON = [
    {"time": "2025-01-01", "et": 80.0},
    {"time": "2025-02-01", "et": 120.0},
]

FCC_JSON = {
    "status": "OK",
    "results": [
        {
            "state_code": "NV",
            "state_name": "Nevada",
            "county_name": "Churchill",
            "county_fips": "32001",
            "state_fips": "32",
        }
    ],
}

NASS_JSON = {
    "data": [
        {
            "commodity_desc": "CORN",
            "class_desc": "ALL CLASSES",
            "Value": "170.0",
            "year": "2023",
        },
        {
            "commodity_desc": "HAY",
            "class_desc": "ALFALFA",
            "Value": "4.5",
            "year": "2023",
        },
        {
            "commodity_desc": "SORGHUM",
            "class_desc": "ALL CLASSES",
            "Value": "60.0",
            "year": "2023",
        },
    ]
}


def auth_headers(client, email: str | None = None) -> dict[str, str] | None:
    email = email or f"u{uuid.uuid4().hex[:10]}@example.com"
    payload = {"name": "Test User", "email": email, "password": "password1"}
    response = client.post("/api/v1/auth/register", json=payload)
    if response.status_code == 409:
        response = client.post("/api/v1/auth/login", json=payload)
    if response.status_code != 200:
        return None
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


def live_enabled() -> bool:
    return os.getenv("NEXTHARVEST_LIVE") == "1"


@pytest.fixture(autouse=True)
def stub_openai_explainer(monkeypatch, request):
    if "test_ai_explainer" in request.node.nodeid:
        return

    async def passthrough(self, strategies, **kwargs):
        self.used_llm = False
        return strategies

    monkeypatch.setattr("app.services.ai_explainer.AiExplainer.explain", passthrough)


@pytest.fixture
def mock_nasa_usda():
    with respx.mock(assert_all_called=False) as router:
        router.get(url__regex=r"https://power\.larc\.nasa\.gov/.*").mock(
            return_value=httpx.Response(200, json=POWER_JSON)
        )
        router.post("https://SDMDataAccess.sc.egov.usda.gov/Tabular/post.rest").mock(
            return_value=httpx.Response(200, json=SDA_JSON)
        )
        router.post("https://openet-api.org/raster/timeseries/polygon").mock(
            return_value=httpx.Response(200, json=OPENET_JSON)
        )
        router.post("https://openet-api.org/raster/timeseries/point").mock(
            return_value=httpx.Response(200, json=OPENET_JSON)
        )
        router.get(url__regex=r"https://geo\.fcc\.gov/api/census/area.*").mock(
            return_value=httpx.Response(200, json=FCC_JSON)
        )
        router.get(url__regex=r"https://quickstats\.nass\.usda\.gov/api/api_GET/.*").mock(
            return_value=httpx.Response(200, json=NASS_JSON)
        )
        yield router
