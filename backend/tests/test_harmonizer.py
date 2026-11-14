from unittest.mock import AsyncMock

import pytest

from app.connectors.openet_client import OpenEtClient
from app.schemas.rotation_models import FieldAnalyzeRequest
from app.services.harmonizer import GeoHarmonizerService
from tests.conftest import DEMO_GEOMETRY, SOIL_PROFILE


def _field() -> FieldAnalyzeRequest:
    return FieldAnalyzeRequest(name="Demo", current_crop="Alfafa", geometry=DEMO_GEOMETRY)


@pytest.mark.asyncio
async def test_summarize_prefers_openet_over_power(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(OpenEtClient, "enabled", True)
    monkeypatch.setattr(
        "app.services.harmonizer.NasaPowerClient.fetch_point",
        AsyncMock(return_value={"annual_precip_mm": 132.4, "annual_et_mm": 30.0, "mean_gwetroot": 0.4}),
    )
    monkeypatch.setattr(
        "app.services.harmonizer.UsdaSdaSoilsClient.fetch_polygon",
        AsyncMock(return_value={"ok": True, "profile": SOIL_PROFILE}),
    )
    monkeypatch.setattr(
        "app.services.harmonizer.OpenEtClient.fetch_polygon",
        AsyncMock(return_value={"ok": True, "annual_et_mm": 1180.0}),
    )
    result = await GeoHarmonizerService().summarize(_field())
    assert result.complete is True
    assert result.et_source == "openet"
    assert result.summary.annual_precip_mm == 132.4
    assert result.summary.annual_et_demand_mm == 1180.0
    assert result.summary.water_balance_deficit_mm == pytest.approx(132.4 - 1180.0)
    assert result.summary.soil_profile.mapunit_name.startswith("Dia loam")
    assert result.summary.bare_field_months == []
    assert result.lat == pytest.approx(39.475, abs=1e-6)


@pytest.mark.asyncio
async def test_summarize_falls_back_to_power_et(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(OpenEtClient, "enabled", True)
    monkeypatch.setattr(
        "app.services.harmonizer.NasaPowerClient.fetch_point",
        AsyncMock(return_value={"annual_precip_mm": 132.4, "annual_et_mm": 30.0}),
    )
    monkeypatch.setattr(
        "app.services.harmonizer.UsdaSdaSoilsClient.fetch_polygon",
        AsyncMock(return_value={"ok": True, "profile": SOIL_PROFILE}),
    )
    monkeypatch.setattr(
        "app.services.harmonizer.OpenEtClient.fetch_polygon",
        AsyncMock(side_effect=RuntimeError("quota")),
    )
    result = await GeoHarmonizerService().summarize(_field())
    assert result.complete is True
    assert result.et_source == "power"
    assert result.summary.annual_et_demand_mm == 30.0
    assert any("OpenET" in item for item in result.failures)


@pytest.mark.asyncio
async def test_summarize_survives_power_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(OpenEtClient, "enabled", False)
    monkeypatch.setattr(
        "app.services.harmonizer.NasaPowerClient.fetch_point",
        AsyncMock(side_effect=RuntimeError("timeout")),
    )
    monkeypatch.setattr(
        "app.services.harmonizer.UsdaSdaSoilsClient.fetch_polygon",
        AsyncMock(return_value={"ok": True, "profile": SOIL_PROFILE}),
    )
    result = await GeoHarmonizerService().summarize(_field())
    assert result.complete is False
    assert result.climate_ok is False
    assert result.soil_ok is True
    assert result.summary.soil_profile.hydrologic_group == "B"
    assert any("NASA POWER" in item for item in result.failures)
