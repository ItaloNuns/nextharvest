from functools import lru_cache
from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict

BACKEND_DIR = Path(__file__).resolve().parent.parent
ENV_FILE = BACKEND_DIR / ".env"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=ENV_FILE,
        env_file_encoding="utf-8",
        extra="ignore",
    )

    database_url: str = (
        "postgresql+asyncpg://nextharvest:nextharvest@127.0.0.1:5433/nextharvest"
    )
    redis_url: str = "redis://localhost:6379/0"
    nasa_earthdata_username: str = ""
    nasa_earthdata_password: str = ""
    nass_api_key: str = ""
    ams_api_key: str = ""
    openet_api_key: str = ""
    gemini_api_key: str = ""
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    jwt_secret: str = "nextharvest-dev-secret-change-me"
    jwt_expire_minutes: int = 10080


@lru_cache
def get_settings() -> Settings:
    return Settings()