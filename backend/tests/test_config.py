import os

from app.config import BACKEND_DIR, ENV_FILE, get_settings


def _env_has_non_empty_value(path, key: str) -> bool:
    if not path.is_file():
        return False
    prefix = f"{key}="
    for line in path.read_text(encoding="utf-8").splitlines():
        if line.startswith(prefix):
            return bool(line[len(prefix) :].strip())
    return False


def test_env_file_resolves_to_backend_dotenv() -> None:
    assert ENV_FILE == BACKEND_DIR / ".env"
    assert BACKEND_DIR.name == "backend"


def test_settings_loads_backend_dotenv_when_cwd_is_repo_root(monkeypatch) -> None:
    monkeypatch.chdir(BACKEND_DIR.parent)
    monkeypatch.delenv("OPENAI_API_KEY", raising=False)
    get_settings.cache_clear()
    settings = get_settings()
    from_file = _env_has_non_empty_value(ENV_FILE, "OPENAI_API_KEY")
    assert bool(settings.openai_api_key) == from_file
    assert not os.path.isfile(".env")