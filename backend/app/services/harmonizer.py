from app.schemas.rotation_models import FieldAnalyzeRequest, HarmonizedSummary


class GeoHarmonizerService:
    """Fuse satellite and soil inputs onto the field (section 4.2)."""

    async def summarize(self, field: FieldAnalyzeRequest) -> HarmonizedSummary:
        raise NotImplementedError(
            "GeoHarmonizerService.summarize is the spatial-temporal fusion entry point "
            f"for {field.current_crop}."
        )
