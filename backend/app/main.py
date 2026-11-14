import logging
from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from redis.asyncio import Redis

from app.api.v1.router import api_router
from app.config import get_settings
from app.db.session import engine, init_db
from app.schemas.rotation_models import HealthResponse

logger = logging.getLogger("nextharvest")


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    app.state.db_ok = False
    app.state.redis = None
    try:
        await init_db()
        app.state.db_ok = True
    except Exception:
        logger.exception("PostgreSQL/PostGIS unavailable; continuing without persistence")

    client: Redis | None = None
    try:
        client = Redis.from_url(settings.redis_url, socket_connect_timeout=2)
        await client.ping()
        app.state.redis = client
    except Exception:
        logger.exception("Redis unavailable; continuing without cache")
        if client is not None:
            await client.aclose()
    yield
    redis_client: Redis | None = app.state.redis
    if redis_client is not None:
        await redis_client.aclose()
    await engine.dispose()


app = FastAPI(
    title="NextHarvest API",
    version="0.1.0",
    description=(
        "Apoio à decisão de rotação de culturas com dados NASA e USDA. "
        "Nesta fase as rotas devolvem contratos válidos com dados placeholder."
    ),
    lifespan=lifespan,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.include_router(api_router, prefix="/api/v1")


@app.get("/health", response_model=HealthResponse, tags=["health"])
async def health() -> HealthResponse:
    database = "up" if app.state.db_ok else "down"
    redis_status = "up" if app.state.redis is not None else "down"
    status = "ok" if database == "up" and redis_status == "up" else "degraded"
    return HealthResponse(status=status, database=database, redis=redis_status)
