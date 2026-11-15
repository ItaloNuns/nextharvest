import pytest
from fastapi.testclient import TestClient

from app.config import get_settings
from app.main import app
from tests.conftest import ANALYZE_BODY, RECOMMEND_PRIORITIES, auth_headers


def _recommend_body(field_id: str) -> dict:
    return {"field_id": field_id, "priorities": RECOMMEND_PRIORITIES}


def test_recommend_requires_auth() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/rotations/recommend",
            json=_recommend_body("fld_does_not_exist"),
        )
        assert response.status_code == 401


def test_recommend_after_analyze(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        created = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY, headers=headers or {})
        if health["database"] != "up":
            assert created.status_code == 401
            return
        assert created.status_code == 200, created.text
        field_id = created.json()["field_id"]
        response = client.post(
            "/api/v1/rotations/recommend",
            json=_recommend_body(field_id),
            headers=headers,
        )
        assert response.status_code == 200, response.text
        body = response.json()
        assert body["placeholder"] is False
        assert body["field_id"] == field_id
        assert body["harmonized_summary"]["annual_precip_mm"] == 15.0
        assert len(body["strategies"]) == 3
        assert body["strategies"][0]["is_baseline"] is True
        assert "Alfalfa" in body["strategies"][0]["sequence"][0]
        assert body["location"]["lat"] == pytest.approx(39.475, abs=1e-3)
        assert body["location"]["lon"] == pytest.approx(-118.775, abs=1e-3)
        assert body["location"]["state"] == "NV"
        assert body["location"]["county"] == "Churchill"
        assert body["nass_used"] is bool(get_settings().nass_api_key)
        evidence = " ".join(body["strategies"][0]["explanation"]["supporting_evidence"])
        gaps = " ".join(body["strategies"][0]["explanation"]["information_gaps_and_uncertainty"])
        assert "15.0 mm" in evidence
        if body["harmonized_summary"]["annual_et_demand_mm"] > 0:
                assert "evaporative demand" in evidence
        if get_settings().nass_api_key:
            assert "QuickStats" in evidence
        else:
            assert "were not queried" in gaps


def test_recommend_unknown_field() -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        response = client.post(
            "/api/v1/rotations/recommend",
            json=_recommend_body("fld_does_not_exist"),
            headers=headers or {},
        )
        if health["database"] != "up":
            assert response.status_code in {401, 503}
            return
        assert response.status_code == 404
