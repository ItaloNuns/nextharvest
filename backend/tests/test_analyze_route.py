from fastapi.testclient import TestClient

from app.config import get_settings
from app.main import app
from tests.conftest import ANALYZE_BODY, auth_headers


def test_analyze_requires_auth() -> None:
    with TestClient(app) as client:
        response = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY)
        assert response.status_code == 401


def test_analyze_returns_real_summary_with_mocked_sources(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        if health["database"] != "up":
            assert headers is None
            return
        assert headers is not None
        response = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY, headers=headers)
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["placeholder"] is False
        assert body["field_id"].startswith("fld_")
        assert body["summary"]["annual_precip_mm"] == 15.0
        expected_et = 200.0 if get_settings().openet_api_key else 30.0
        assert body["summary"]["annual_et_demand_mm"] == expected_et
        assert body["summary"]["water_balance_deficit_mm"] == round(15.0 - expected_et, 2)
        assert body["summary"]["soil_profile"]["mapunit_name"].startswith("Dia loam")
        health_payload = body["health"]
        assert health_payload["overall"] in {"ok", "warning", "critical"}
        dim_ids = {item["id"] for item in health_payload["dimensions"]}
        assert dim_ids == {"water", "soil", "sources"}

        listed = client.get("/api/v1/fields/", headers=headers)
        assert listed.status_code == 200, listed.text
        ids = [item["id"] for item in listed.json()]
        assert body["field_id"] in ids


def test_analyze_rejects_non_polygon() -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        if health["database"] != "up":
            assert headers is None
            return
        assert headers is not None
        response = client.post(
            "/api/v1/fields/analyze",
            json={
                "name": "X",
                "current_crop": "Alfafa",
                "geometry": {"type": "Point", "coordinates": [0, 0]},
            },
            headers=headers,
        )
        assert response.status_code == 422


def test_diagnostics_roundtrip(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        created = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY, headers=headers or {})
        if health["database"] != "up":
            assert created.status_code == 401
            return
        assert created.status_code == 200, created.text
        field_id = created.json()["field_id"]
        diagnostics = client.get(f"/api/v1/diagnostics/{field_id}", headers=headers)
        assert diagnostics.status_code == 200, diagnostics.text
        diag = diagnostics.json()
        assert diag["summary"]["annual_precip_mm"] == 15.0
        created_health = created.json()["health"]
        assert diag["health"]["overall"] == created_health["overall"]
        assert diag["health"]["data_quality"] == created_health["data_quality"]
        assert {item["id"] for item in diag["health"]["dimensions"]} == {
            "water",
            "soil",
            "sources",
        }
        missing = client.get("/api/v1/diagnostics/fld_does_not_exist", headers=headers)
        assert missing.status_code == 404


def test_other_user_cannot_read_field(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        owner = auth_headers(client)
        other = auth_headers(client)
        if health["database"] != "up":
            assert owner is None
            return
        assert owner is not None and other is not None
        created = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY, headers=owner)
        assert created.status_code == 200, created.text
        field_id = created.json()["field_id"]
        diagnostics = client.get(f"/api/v1/diagnostics/{field_id}", headers=other)
        recommend = client.post(
            "/api/v1/rotations/recommend",
            json={"field_id": field_id, "priorities": {"water_savings": 5}},
            headers=other,
        )
        assert diagnostics.status_code == 404
        assert recommend.status_code == 404
