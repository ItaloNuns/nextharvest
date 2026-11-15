import logging
from collections.abc import AsyncIterator

from sqlalchemy import text
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

from app.config import get_settings

logger = logging.getLogger("nextharvest.db")

engine = create_async_engine(
    get_settings().database_url,
    pool_pre_ping=True,
    connect_args={"timeout": 3},
)
SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def init_db() -> None:
    from app.db.models import Base

    async with engine.begin() as conn:
        await conn.execute(text("CREATE EXTENSION IF NOT EXISTS postgis"))
        await conn.run_sync(Base.metadata.create_all)
        await conn.execute(
            text("ALTER TABLE fields ADD COLUMN IF NOT EXISTS last_summary jsonb")
        )
        await conn.execute(
            text("ALTER TABLE fields ADD COLUMN IF NOT EXISTS user_id VARCHAR(64)")
        )
        await conn.execute(
            text("ALTER TABLE users ADD COLUMN IF NOT EXISTS name VARCHAR(120)")
        )
        await conn.execute(text("UPDATE users SET name = '' WHERE name IS NULL"))
        await conn.execute(text("ALTER TABLE users ALTER COLUMN name SET NOT NULL"))
        await conn.execute(text("ALTER TABLE users ALTER COLUMN name SET DEFAULT ''"))
        await conn.execute(
            text(
                """
                DO $$ BEGIN
                  ALTER TABLE fields
                    ADD CONSTRAINT fields_user_id_fkey
                    FOREIGN KEY (user_id) REFERENCES users(id);
                EXCEPTION
                  WHEN duplicate_object THEN NULL;
                  WHEN undefined_object THEN NULL;
                  WHEN undefined_table THEN NULL;
                END $$;
                """
            )
        )
    logger.info("PostGIS schema ready")


async def get_session() -> AsyncIterator[AsyncSession]:
    async with SessionLocal() as session:
        yield session
