"""Rewrite rotation explanations with OpenAI structured output + in-memory RAG."""

from __future__ import annotations

import logging
from typing import Any

from openai import AsyncOpenAI
from pydantic import BaseModel

from app.config import ENV_FILE, get_settings
from app.schemas.rotation_models import (
    FarmerPriorities,
    HarmonizedSummary,
    Location,
    RotationExplanation,
    RotationStrategy,
)
from app.services.agronomic_rag import (
    codes_from_labels,
    extra_tags_from_summary,
    retrieve_agronomic_snippets,
)

logger = logging.getLogger("nextharvest.explainer")

_SYSTEM_PROMPT = """You are an agronomist explaining crop rotations for farmers.
Respond in clear English; avoid unnecessary jargon.
Return structured JSON with a `strategies` list: one item per strategy_id
from the request, each with strategy_id and the five explanation fields
(why_suggested, supporting_evidence, expected_benefits,
information_gaps_and_uncertainty, risks_requiring_local_review).

Rules:
- Use ONLY numbers and facts present in the user JSON (rainfall, ET, scores, soil, county).
- Do not invent SMAP, NDVI, AMS, ECOSTRESS, or bare-soil months if the JSON does not include useful values.
- If rootzone_source is "power_gwetroot", cite NASA POWER GWETROOT for smap_rootzone_anomaly_z; do NOT call it SMAP.
- If bare_field_months is non-empty, they are a POWER proxy (low ET + low GWETROOT), not Sentinel/NDVI.
- If rootzone_source is "none" and bare_field_months is empty, state that satellite SMAP and optical bare-soil series were not used.
- If nass_used is false, do not claim USDA NASS was queried.
- Cite NASA POWER, SSURGO, and OpenET only when the summary has precipitation, soil, or ET > 0.
- Always include a risk that requires review with a local agronomist.
- Use RAG snippets only as agronomic context; do not contradict the field numbers.
"""


class ExplainerStrategyOutput(BaseModel):
    strategy_id: str
    explanation: RotationExplanation


class ExplainerBatch(BaseModel):
    strategies: list[ExplainerStrategyOutput]

    def explanations_by_strategy_id(self) -> dict[str, RotationExplanation]:
        return {item.strategy_id: item.explanation for item in self.strategies}


class AiExplainer:
    def __init__(
        self,
        api_key: str | None = None,
        model: str | None = None,
        client: Any | None = None,
    ) -> None:
        settings = get_settings()
        if api_key is None:
            api_key = settings.openai_api_key
        if model is None:
            model = settings.openai_model
        self.api_key = api_key or ""
        self.model = model or "gpt-4o-mini"
        self._client = client
        self.used_llm = False

    @property
    def enabled(self) -> bool:
        return bool(self.api_key) or self._client is not None

    async def explain(
        self,
        strategies: list[RotationStrategy],
        *,
        summary: HarmonizedSummary,
        priorities: FarmerPriorities,
        location: Location,
        nass_used: bool,
        http_client: Any | None = None,
    ) -> list[RotationStrategy]:
        self.used_llm = False
        if not strategies:
            return strategies
        if not self.enabled:
            logger.info("OpenAI skipped: OPENAI_API_KEY not set (expected in %s)", ENV_FILE)
            return strategies
        try:
            batch = await self._complete(strategies, summary, priorities, location, nass_used)
        except Exception:
            logger.exception("OpenAI explainer failed; keeping template explanations")
            return strategies
        if batch is None or not batch.strategies:
            logger.warning(
                "OpenAI returned no parsed explanations (model=%s); keeping templates",
                self.model,
            )
            return strategies
        by_id = batch.explanations_by_strategy_id()
        expected_ids = {strategy.strategy_id for strategy in strategies}
        missing_ids = expected_ids - set(by_id.keys())
        if missing_ids:
            logger.warning(
                "OpenAI explanations missing strategy_ids: %s",
                sorted(missing_ids),
            )
        updated: list[RotationStrategy] = []
        replaced = False
        for strategy in strategies:
            extra = by_id.get(strategy.strategy_id)
            if extra is None:
                updated.append(strategy)
                continue
            updated.append(strategy.model_copy(update={"explanation": extra}))
            replaced = True
        if not replaced:
            logger.warning(
                "OpenAI batch had no matching strategy_ids for this recommendation (model=%s)",
                self.model,
            )
        self.used_llm = replaced
        return updated

    async def _complete(
        self,
        strategies: list[RotationStrategy],
        summary: HarmonizedSummary,
        priorities: FarmerPriorities,
        location: Location,
        nass_used: bool,
    ) -> ExplainerBatch | None:
        labels = [item for strategy in strategies for item in strategy.sequence]
        codes = codes_from_labels(labels)
        rag_context = retrieve_agronomic_snippets(codes, extra_tags_from_summary(summary))
        payload = {
            "location": location.model_dump(),
            "harmonized_summary": summary.model_dump(),
            "priorities": priorities.model_dump(),
            "nass_used": nass_used,
            "et_available": summary.annual_et_demand_mm > 0,
            "smap_used": False,
            "rootzone_source": summary.rootzone_source,
            "gwetroot_used": summary.rootzone_source == "power_gwetroot",
            "rag_context": rag_context,
            "strategies": [
                {
                    "strategy_id": item.strategy_id,
                    "name": item.name,
                    "is_baseline": item.is_baseline,
                    "sequence": item.sequence,
                    "metrics_radar": item.metrics_radar.model_dump(),
                }
                for item in strategies
            ],
        }
        client = self._client
        close = False
        if client is None:
            client = AsyncOpenAI(api_key=self.api_key, timeout=30.0)
            close = True
        try:
            parsed = await self._parse(client, payload)
        finally:
            if close:
                await client.close()
        return parsed

    async def _parse(self, client: Any, payload: dict[str, Any]) -> ExplainerBatch | None:
        kwargs = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": _user_content(payload)},
            ],
            "response_format": ExplainerBatch,
        }
        completions = client.chat.completions
        if hasattr(completions, "parse"):
            response = await completions.parse(**kwargs)
        else:
            response = await client.beta.chat.completions.parse(**kwargs)
        message = response.choices[0].message
        parsed = getattr(message, "parsed", None)
        if parsed is None:
            return None
        if isinstance(parsed, ExplainerBatch):
            return parsed
        return ExplainerBatch.model_validate(parsed)


def _user_content(payload: dict[str, Any]) -> str:
    import json

    strategy_ids = [
        item["strategy_id"] for item in payload.get("strategies", []) if "strategy_id" in item
    ]
    ids_line = ", ".join(strategy_ids) if strategy_ids else "(none)"
    return (
        "Return a `strategies` item for each strategy_id with the same id "
        f"and a complete explanation. Expected strategy_ids: {ids_line}.\n"
        + json.dumps(payload, ensure_ascii=False)
    )