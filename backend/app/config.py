from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
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
    jwt_secret: str = "nextharvest-dev-secret-change-me"
    jwt_expire_minutes: int = 10080


@lru_cache
def get_settings() -> Settings:
    return Settings()
