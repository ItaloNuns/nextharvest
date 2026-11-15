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


def test_delete_requires_auth() -> None:
    with TestClient(app) as client:
        response = client.delete("/api/v1/fields/fld_x")
        assert response.status_code == 401


def test_delete_unknown_field() -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        response = client.delete(
            "/api/v1/fields/fld_does_not_exist",
            headers=headers or {},
        )
        if health["database"] != "up":
            assert response.status_code in {401, 503}
            return
        assert response.status_code == 404


def test_delete_after_analyze_removes_from_list(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        created = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY, headers=headers or {})
        if health["database"] != "up":
            assert created.status_code == 401
            return
        assert created.status_code == 200, created.text
        field_id = created.json()["field_id"]
        deleted = client.delete(f"/api/v1/fields/{field_id}", headers=headers)
        assert deleted.status_code == 204, deleted.text
        listed = client.get("/api/v1/fields/", headers=headers)
        assert listed.status_code == 200
        ids = [item["id"] for item in listed.json()]
        assert field_id not in ids


def test_delete_removes_simulation_history(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client)
        created = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY, headers=headers or {})
        if health["database"] != "up":
            assert created.status_code == 401
            return
        field_id = created.json()["field_id"]
        simulated = client.post(
            "/api/v1/rotations/simulate",
            json=_simulate_body(field_id),
            headers=headers,
        )
        assert simulated.status_code == 200, simulated.text
        latest = client.get(f"/api/v1/fields/{field_id}/simulations/latest", headers=headers)
        assert latest.status_code == 200
        deleted = client.delete(f"/api/v1/fields/{field_id}", headers=headers)
        assert deleted.status_code == 204
        missing = client.get(f"/api/v1/fields/{field_id}/simulations/latest", headers=headers)
        assert missing.status_code == 404


def test_other_user_cannot_delete_field(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        owner = auth_headers(client)
        other = auth_headers(client)
        created = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY, headers=owner or {})
        if health["database"] != "up":
            assert created.status_code == 401
            return
        field_id = created.json()["field_id"]
        blocked = client.delete(f"/api/v1/fields/{field_id}", headers=other)
        assert blocked.status_code == 404
        still = client.get("/api/v1/fields/", headers=owner)
        assert field_id in [item["id"] for item in still.json()]