from pydantic import BaseModel, ConfigDict, Field, field_validator

REGISTER_BODY_EXAMPLE: dict[str, str] = {
    "name": "Maria Silva",
    "email": "farmer@example.com",
    "password": "password1",
}

LOGIN_BODY_EXAMPLE: dict[str, str] = {
    "email": "farmer@example.com",
    "password": "password1",
}


def _normalize_email(value: str) -> str:
    email = value.strip().lower()
    local, _, domain = email.partition("@")
    if not local or not domain or "." not in domain:
        raise ValueError("Invalid email")
    return email


class RegisterRequest(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [REGISTER_BODY_EXAMPLE]})

    name: str = Field(min_length=1, max_length=120)
    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=8, max_length=72)

    @field_validator("name")
    @classmethod
    def name_is_nonempty(cls, value: str) -> str:
        name = value.strip()
        if not name:
            raise ValueError("Name must not be blank")
        return name

    @field_validator("email")
    @classmethod
    def email_is_valid(cls, value: str) -> str:
        return _normalize_email(value)


class LoginRequest(BaseModel):
    model_config = ConfigDict(json_schema_extra={"examples": [LOGIN_BODY_EXAMPLE]})

    email: str = Field(min_length=3, max_length=320)
    password: str = Field(min_length=1, max_length=72)

    @field_validator("email")
    @classmethod
    def email_is_valid(cls, value: str) -> str:
        return _normalize_email(value)


class UserPublic(BaseModel):
    id: str
    name: str
    email: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserPublic
