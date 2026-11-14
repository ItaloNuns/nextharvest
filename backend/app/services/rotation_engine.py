from app.schemas.rotation_models import (
    FarmerPriorities,
    HarmonizedSummary,
    RotationStrategy,
)


class RotationEngine:
    """Score the current rotation plus water and soil alternatives (section 6.2)."""

    async def recommend(
        self,
        summary: HarmonizedSummary,
        priorities: FarmerPriorities,
    ) -> list[RotationStrategy]:
        raise NotImplementedError(
            "RotationEngine.recommend is the MCDA entry point "
            f"(precip {summary.annual_precip_mm} mm, water priority {priorities.water_savings}). "
            "It must return the baseline, a water-resilient rotation and a soil-and-income rotation."
        )
