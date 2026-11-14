from fastapi.testclient import TestClient

from app.main import app
from tests.conftest import ANALYZE_BODY


def test_analyze_returns_real_summary_with_mocked_sources(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        response = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY)
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["placeholder"] is False
    assert body["field_id"].startswith("fld_")
    assert body["summary"]["annual_precip_mm"] == 15.0
    assert body["summary"]["soil_profile"]["mapunit_name"].startswith("Dia loam")


def test_analyze_rejects_non_polygon() -> None:
    with TestClient(app) as client:
        response = client.post(
            "/api/v1/fields/analyze",
            json={
                "name": "X",
                "current_crop": "Alfafa",
                "geometry": {"type": "Point", "coordinates": [0, 0]},
            },
        )
    assert response.status_code == 422


def test_diagnostics_roundtrip(mock_nasa_usda) -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        created = client.post("/api/v1/fields/analyze", json=ANALYZE_BODY)
        assert created.status_code == 200, created.text
        field_id = created.json()["field_id"]
        diagnostics = client.get(f"/api/v1/diagnostics/{field_id}")
        if health["database"] != "up":
            assert diagnostics.status_code == 503
            return
        assert diagnostics.status_code == 200, diagnostics.text
        assert diagnostics.json()["summary"]["annual_precip_mm"] == 15.0
        missing = client.get("/api/v1/diagnostics/fld_does_not_exist")
        assert missing.status_code == 404
