from datetime import datetime
from typing import Any

from geoalchemy2 import Geometry
from sqlalchemy import DateTime, Float, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship


class Base(DeclarativeBase):
    pass


class User(Base):
    __tablename__ = "users"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    name: Mapped[str] = mapped_column(String(120), nullable=False)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )

    fields: Mapped[list["Field"]] = relationship(back_populates="owner")


class Field(Base):
    __tablename__ = "fields"

    id: Mapped[str] = mapped_column(String(64), primary_key=True)
    user_id: Mapped[str | None] = mapped_column(ForeignKey("users.id"), nullable=True, index=True)
    name: Mapped[str] = mapped_column(String(200), nullable=False)
    current_crop: Mapped[str] = mapped_column(String(120), nullable=False)
    geometry: Mapped[Any] = mapped_column(
        Geometry(geometry_type="POLYGON", srid=4326),
        nullable=False,
    )
    last_summary: Mapped[dict | None] = mapped_column(JSONB, nullable=True)
    last_analysis_meta: Mapped[dict | None] = mapped_column(JSONB, nullable=True)

    owner: Mapped[User | None] = relationship(back_populates="fields")
    simulations: Mapped[list["Simulation"]] = relationship(
        back_populates="field",
        cascade="all, delete-orphan",
    )


class Simulation(Base):
    __tablename__ = "simulations"

    id: Mapped[int] = mapped_column(primary_key=True, autoincrement=True)
    field_id: Mapped[str] = mapped_column(ForeignKey("fields.id"), nullable=False)
    delta_precip_pct: Mapped[float] = mapped_column(Float, nullable=False)
    delta_temp_c: Mapped[float] = mapped_column(Float, nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        server_default=func.now(),
        nullable=False,
    )
    result: Mapped[dict] = mapped_column(JSONB, nullable=False)

    field: Mapped[Field] = relationship(back_populates="simulations")
