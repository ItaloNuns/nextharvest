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

_SYSTEM_PROMPT = """Você é um agrônomo que explica rotações de culturas para produtores rurais.
Responda em português claro, sem jargão desnecessário.
Retorne o JSON estruturado com a lista `strategies`: um item por strategy_id
do pedido, cada um com strategy_id e os 5 campos em explanation
(why_suggested, supporting_evidence, expected_benefits,
information_gaps_and_uncertainty, risks_requiring_local_review).

Regras:
- Use APENAS números e fatos presentes no JSON do usuário (chuva, ET, scores, solo, condado).
- Não invente SMAP, NDVI, AMS, ECOSTRESS ou meses de solo nu se o JSON não os tiver com valor útil.
- Se smap_rootzone_anomaly_z for 0 e bare_field_months estiver vazio, diga que SMAP e solo nu não entraram nesta recomendação.
- Se nass_used for false, não afirme que o USDA NASS foi consultado.
- Cite NASA POWER, SSURGO e OpenET somente quando o resumo tiver precipitação, solo ou ET > 0.
- Sempre inclua risco que exige revisão com agrônomo local.
- Use os trechos RAG só como contexto agronômico; não contradiga os números do talhão.
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
            "smap_used": summary.smap_rootzone_anomaly_z != 0,
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
    ids_line = ", ".join(strategy_ids) if strategy_ids else "(nenhum)"
    return (
        "Gere em `strategies` exatamente um item por strategy_id, com o mesmo id "
        f"e explanation completa. strategy_ids esperados: {ids_line}.\n"
        + json.dumps(payload, ensure_ascii=False)
    )
