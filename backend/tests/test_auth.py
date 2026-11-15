from fastapi.testclient import TestClient

from app.main import app
from tests.conftest import auth_headers


def test_register_login_and_me() -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        email = f"farmer_{health['database']}@example.com"
        registered = client.post(
            "/api/v1/auth/register",
            json={"name": "Maria Demo", "email": email, "password": "password1"},
        )
        if health["database"] != "up":
            assert registered.status_code == 503
            return
        if registered.status_code == 409:
            registered = client.post(
                "/api/v1/auth/login",
                json={"email": email, "password": "password1"},
            )
        assert registered.status_code == 200, registered.text
        body = registered.json()
        assert body["token_type"] == "bearer"
        assert body["access_token"]
        assert body["user"]["email"] == email
        assert body["user"]["name"] == "Maria Demo"
        headers = {"Authorization": f"Bearer {body['access_token']}"}
        me = client.get("/api/v1/auth/me", headers=headers)
        assert me.status_code == 200, me.text
        assert me.json()["email"] == email
        assert me.json()["name"] == "Maria Demo"

        logged = client.post(
            "/api/v1/auth/login",
            json={"email": email.upper(), "password": "password1"},
        )
        assert logged.status_code == 200, logged.text


def test_register_duplicate_email() -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        email = f"dup_{id(client)}@example.com"
        headers = auth_headers(client, email)
        if health["database"] != "up":
            assert headers is None
            return
        assert headers is not None
        again = client.post(
            "/api/v1/auth/register",
            json={"name": "Other", "email": email.upper(), "password": "password1"},
        )
        assert again.status_code == 409


def test_login_rejects_bad_password() -> None:
    with TestClient(app) as client:
        health = client.get("/health").json()
        headers = auth_headers(client, "badpass@example.com")
        if health["database"] != "up":
            assert headers is None
            return
        response = client.post(
            "/api/v1/auth/login",
            json={"email": "badpass@example.com", "password": "wrong-password"},
        )
        assert response.status_code == 401


def test_me_requires_token() -> None:
    with TestClient(app) as client:
        response = client.get("/api/v1/auth/me")
        assert response.status_code == 401


def test_me_rejects_invalid_token() -> None:
    with TestClient(app) as client:
        response = client.get(
            "/api/v1/auth/me",
            headers={"Authorization": "Bearer not-a-real-token"},
        )
        assert response.status_code == 401
