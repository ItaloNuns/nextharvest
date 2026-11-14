from fastapi.testclient import TestClient

from app.main import app
from tests.conftest import ANALYZE_BODY, RECOMMEND_PRIORITIES, auth_headers


def _simulate_body(field_id: str) -> dict:
    return {
        "field_id": field_id,
        "delta_precip_pct": -25,
        "delta_temp_c": 2,
        "priorities": RECOMMEND_PRIORITIES,
    }


def test_simulate_requires_auth() -> None:
    with TestClient(app) as client:
        response = client.post("/api/v1/rotations/simulate", json=_simulate_body("fld_x"))
        assert response.status_code == 401


def test_simulate_after_analyze_changes_water_score(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        created = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY, headers=headers or {})
        if health["database"] != "up":
            assert created.status_code == 401
            return
        assert created.status_code == 200, created.text
        field_id = created.json()["field_id"]
        recommend = client.post(
            "/api/v1/rotations/recommend",
            json={"field_id": field_id, "priorities": RECOMMEND_PRIORITIES},
            headers=headers,
        )
        simulated = client.post(
            "/api/v1/rotations/simulate",
            json=_simulate_body(field_id),
            headers=headers,
        )
        assert simulated.status_code == 200, simulated.text
        body = simulated.json()
        assert body["placeholder"] is False
        assert body["field_id"] == field_id
        assert len(body["strategies"]) == 3
        rec_water = recommend.json()["strategies"][0]["metrics_radar"]["water_efficiency_score"]
        sim_water = body["strategies"][0]["metrics_radar"]["water_efficiency_score"]
        assert sim_water <= rec_water


def test_simulate_without_priorities_uses_demo_defaults(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        created = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY, headers=headers or {})
        if health["database"] != "up":
            assert created.status_code == 401
            return
        field_id = created.json()["field_id"]
        response = client.post(
            "/api/v1/rotations/simulate",
            json={
                "field_id": field_id,
                "delta_precip_pct": -25,
                "delta_temp_c": 2,
            },
            headers=headers,
        )
        assert response.status_code == 200, response.text


def test_simulate_unknown_field() -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        response = client.post(
            "/api/v1/rotations/simulate",
            json=_simulate_body("fld_does_not_exist"),
            headers=headers or {},
        )
        if health["database"] != "up":
            assert response.status_code in {401, 503}
            return
        assert response.status_code == 404
