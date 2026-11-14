from app.config import get_settings
from app.schemas.rotation_models import RotationStrategy


class AiExplainer:
    """Fill the five explanation fields with Gemini structured output (section 6.3)."""

    def __init__(self, api_key: str | None = None) -> None:
        if api_key is None:
            api_key = get_settings().gemini_api_key
        self.api_key = api_key

    @property
    def enabled(self) -> bool:
        return bool(self.api_key)

    async def explain(self, strategies: list[RotationStrategy]) -> list[RotationStrategy]:
        if not self.enabled:
            return strategies
        raise NotImplementedError(
            "Gemini structured output is not implemented yet. "
            "Set GEMINI_API_KEY only after AiExplainer.explain is wired."
        )
