from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.schemas.rotation_models import (
    FarmerPriorities,
    HarmonizedSummary,
    Location,
    MetricsRadar,
    RotationExplanation,
    RotationStrategy,
    SoilProfile,
)
from app.services.ai_explainer import AiExplainer, ExplainerBatch, ExplainerStrategyOutput
from app.services.explanation_templates import explain_strategy


def _summary() -> HarmonizedSummary:
    return HarmonizedSummary(
        annual_precip_mm=15.0,
        annual_et_demand_mm=0,
        water_balance_deficit_mm=15.0,
        smap_rootzone_anomaly_z=0,
        bare_field_months=[],
        soil_profile=SoilProfile(
            mapunit_name="Dia loam, 0 to 2 percent slopes",
            organic_matter_pct=1.2,
            available_water_capacity_cm_cm=0.16,
            drainage_class="Well drained",
            hydrologic_group="B",
            erosion_k_factor=0.32,
        ),
    )


def _radar() -> MetricsRadar:
    return MetricsRadar(
        water_efficiency_score=40,
        soil_health_organic_matter_score=65,
        nitrogen_fixation_score=85,
        erosion_protection_score=60,
        pest_cycle_disruption_score=30,
        market_viability_score=88,
    )


def _strategy() -> RotationStrategy:
    radar = _radar()
    return RotationStrategy(
        strategy_id="rot_baseline",
        name="Estratégia 1 (Atual): Alfafa",
        is_baseline=True,
        sequence=["Alfafa"],
        metrics_radar=radar,
        explanation=explain_strategy(
            role="baseline",
            sequence_label="Alfafa",
            current_crop="Alfafa",
            summary=_summary(),
            priorities=FarmerPriorities(),
            radar=radar,
            baseline_radar=None,
        ),
    )


def _location() -> Location:
    return Location(lat=39.47, lon=-118.78, state="NV", county="Churchill")


def _llm_explanation() -> RotationExplanation:
    return RotationExplanation(
        why_suggested="Texto gerado pelo modelo para a baseline.",
        supporting_evidence=["Chuva anual de 15.0 mm no diagnóstico POWER."],
        expected_benefits=["Mantém a linha de base da alfafa."],
        information_gaps_and_uncertainty=["SMAP e solo nu não entram nesta recomendação."],
        risks_requiring_local_review=["Validar com agrônomo local antes do plantio."],
    )


def _fake_client(batch: ExplainerBatch | None, *, fail: bool = False) -> SimpleNamespace:
    if fail:
        parse = AsyncMock(side_effect=RuntimeError("openai down"))
    else:
        message = SimpleNamespace(parsed=batch)
        parse = AsyncMock(return_value=SimpleNamespace(choices=[SimpleNamespace(message=message)]))
    return SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(parse=parse)))


@pytest.mark.asyncio
async def test_explain_without_key_keeps_templates() -> None:
    original = _strategy()
    explainer = AiExplainer(api_key="", client=None)
    result = await explainer.explain(
        [original],
        summary=_summary(),
        priorities=FarmerPriorities(),
        location=_location(),
        nass_used=False,
    )
    assert explainer.used_llm is False
    assert result[0].explanation == original.explanation


@pytest.mark.asyncio
async def test_explain_replaces_fields_from_openai() -> None:
    original = _strategy()
    batch = ExplainerBatch(
        strategies=[
            ExplainerStrategyOutput(
                strategy_id="rot_baseline",
                explanation=_llm_explanation(),
            )
        ]
    )
    explainer = AiExplainer(api_key="", client=_fake_client(batch))
    result = await explainer.explain(
        [original],
        summary=_summary(),
        priorities=FarmerPriorities(),
        location=_location(),
        nass_used=False,
    )
    assert explainer.used_llm is True
    assert result[0].explanation.why_suggested == "Texto gerado pelo modelo para a baseline."
    assert "15.0 mm" in result[0].explanation.supporting_evidence[0]


@pytest.mark.asyncio
async def test_explain_falls_back_when_openai_raises() -> None:
    original = _strategy()
    explainer = AiExplainer(api_key="sk-test", client=_fake_client(None, fail=True))
    result = await explainer.explain(
        [original],
        summary=_summary(),
        priorities=FarmerPriorities(),
        location=_location(),
        nass_used=False,
    )
    assert explainer.used_llm is False
    assert result[0].explanation == original.explanation


def test_explainer_batch_json_schema_is_strict_compatible() -> None:
    from openai.lib._pydantic import to_strict_json_schema

    schema = to_strict_json_schema(ExplainerBatch)
    assert schema["type"] == "object"
    props = schema.get("properties", {})
    assert "strategies" in props
    assert props["strategies"]["type"] == "array"
    assert "explanations" not in props
