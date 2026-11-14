from unittest.mock import AsyncMock

import pytest

from app.schemas.rotation_models import FieldAnalyzeRequest
from app.services.harmonizer import GeoHarmonizerService
from tests.conftest import DEMO_GEOMETRY, SOIL_PROFILE


@pytest.mark.asyncio
async def test_summarize_merges_climate_and_soil(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.harmonizer.NasaPowerClient.fetch_point",
        AsyncMock(return_value={"annual_precip_mm": 132.4, "mean_gwetroot": 0.4}),
    )
    monkeypatch.setattr(
        "app.services.harmonizer.UsdaSdaSoilsClient.fetch_polygon",
        AsyncMock(return_value={"ok": True, "profile": SOIL_PROFILE}),
    )
    result = await GeoHarmonizerService().summarize(
        FieldAnalyzeRequest(name="Demo", current_crop="Alfafa", geometry=DEMO_GEOMETRY)
    )
    assert result.complete is True
    assert result.summary.annual_precip_mm == 132.4
    assert result.summary.soil_profile.mapunit_name.startswith("Dia loam")
    assert result.summary.bare_field_months == []
    assert result.lat == pytest.approx(39.475, abs=1e-6)


@pytest.mark.asyncio
async def test_summarize_survives_power_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        "app.services.harmonizer.NasaPowerClient.fetch_point",
        AsyncMock(side_effect=RuntimeError("timeout")),
    )
    monkeypatch.setattr(
        "app.services.harmonizer.UsdaSdaSoilsClient.fetch_polygon",
        AsyncMock(return_value={"ok": True, "profile": SOIL_PROFILE}),
    )
    result = await GeoHarmonizerService().summarize(
        FieldAnalyzeRequest(name="Demo", current_crop="Alfafa", geometry=DEMO_GEOMETRY)
    )
    assert result.complete is False
    assert result.climate_ok is False
    assert result.soil_ok is True
    assert result.summary.soil_profile.hydrologic_group == "B"
    assert any("NASA POWER" in item for item in result.failures)
