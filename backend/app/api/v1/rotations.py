from fastapi import APIRouter

from app.schemas.rotation_models import (
    RecommendRequest,
    RotationRecommendation,
    placeholder_recommendation,
)

router = APIRouter()


@router.post("/recommend", response_model=RotationRecommendation)
async def recommend_rotations(body: RecommendRequest) -> RotationRecommendation:
    return placeholder_recommendation(body.field_id)
