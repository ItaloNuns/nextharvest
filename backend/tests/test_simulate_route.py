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


def test_latest_simulation_requires_auth() -> None:
    with TestClient(app) as client:
        response = client.get("/api/v1/fields/fld_x/simulations/latest")
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

        latest = client.get(f"/api/v1/fields/{field_id}/simulations/latest", headers=headers)
        assert latest.status_code == 200, latest.text
        latest_body = latest.json()
        assert latest_body["simulation"]["field_id"] == field_id
        assert latest_body["simulation"]["delta_precip_pct"] == -25
        assert latest_body["simulation"]["delta_temp_c"] == 2
        assert latest_body["id"] > 0
        assert latest_body["created_at"]


def test_simulate_without_priorities_uses_demo_defaults(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        created = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY, headers=headers or {})
        if health["database"] != "up":
            assert created.status_code == 401
            return
        field_id = created.json()["field_id"]
        missing = client.get(f"/api/v1/fields/{field_id}/simulations/latest", headers=headers)
        assert missing.status_code == 404
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


def test_other_user_cannot_read_latest_simulation(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        owner = auth_headers(client)
        other = auth_headers(client)
        created = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY, headers=owner or {})
        if health["database"] != "up":
            assert created.status_code == 401
            return
        field_id = created.json()["field_id"]
        simulated = client.post(
            "/api/v1/rotations/simulate",
            json=_simulate_body(field_id),
            headers=owner,
        )
        assert simulated.status_code == 200, simulated.text
        blocked = client.get(f"/api/v1/fields/{field_id}/simulations/latest", headers=other)
        assert blocked.status_code == 404
