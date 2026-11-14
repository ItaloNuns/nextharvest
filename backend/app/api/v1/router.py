from fastapi import APIRouter

from app.api.v1 import assistant, auth, diagnostics, fields, rotations, simulator

api_router = APIRouter()
api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(fields.router, prefix="/fields", tags=["fields"])
api_router.include_router(diagnostics.router, prefix="/diagnostics", tags=["diagnostics"])
api_router.include_router(rotations.router, prefix="/rotations", tags=["rotations"])
api_router.include_router(simulator.router, prefix="/rotations", tags=["simulator"])
api_router.include_router(assistant.router, prefix="/glossary", tags=["assistant"])
