"""SQLAlchemy ORM 模型 — M:N 架构"""
import uuid
from datetime import datetime, timezone

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    String, Text, Integer, Numeric, DateTime, ForeignKey, CheckConstraint,
)
from sqlalchemy.dialects.postgresql import ARRAY, JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class User(Base):
    __tablename__ = "users"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    username: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    email: Mapped[str] = mapped_column(String(200), nullable=False, unique=True)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    avatar_url: Mapped[str] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    analyses = relationship("AnalysisHistory", back_populates="user")


class Problem(Base):
    __tablename__ = "problems"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    title_cn: Mapped[str] = mapped_column(String(200), nullable=True)
    difficulty: Mapped[str] = mapped_column(String(10), nullable=False)
    description_cn: Mapped[str] = mapped_column(Text, nullable=True)
    solution_approach: Mapped[str] = mapped_column(Text, nullable=True)
    solution_code: Mapped[str] = mapped_column(Text, nullable=True)
    complexity_time: Mapped[str] = mapped_column(String(50), nullable=True)
    complexity_space: Mapped[str] = mapped_column(String(50), nullable=True)
    key_points = mapped_column(ARRAY(String))
    common_mistakes = mapped_column(ARRAY(String))
    embedding = mapped_column(Vector(768), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    __table_args__ = (
        CheckConstraint("difficulty IN ('easy', 'medium', 'hard')", name="chk_difficulty"),
    )

    tag_links = relationship("ProblemTag", back_populates="problem", cascade="all, delete-orphan")
    analyses = relationship("AnalysisHistory", back_populates="problem")


class Tag(Base):
    __tablename__ = "tags"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    description: Mapped[str] = mapped_column(Text, nullable=True)

    problem_links = relationship("ProblemTag", back_populates="tag", cascade="all, delete-orphan")


class ProblemTag(Base):
    __tablename__ = "problem_tags"

    problem_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("problems.id", ondelete="CASCADE"), primary_key=True
    )
    tag_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("tags.id", ondelete="CASCADE"), primary_key=True
    )

    problem = relationship("Problem", back_populates="tag_links")
    tag = relationship("Tag", back_populates="problem_links")


class EvaluationCriteria(Base):
    __tablename__ = "evaluation_criteria"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    name: Mapped[str] = mapped_column(String(50), nullable=False)
    name_en: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    weight: Mapped[float] = mapped_column(Numeric(5, 2), nullable=False)
    max_score: Mapped[int] = mapped_column(Integer, nullable=False, default=10)
    description: Mapped[str] = mapped_column(Text, nullable=True)
    sort_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)

    __table_args__ = (
        CheckConstraint("weight > 0 AND weight <= 100", name="chk_weight_range"),
    )

    details = relationship("EvaluationDetail", back_populates="criteria")


class AnalysisHistory(Base):
    __tablename__ = "analysis_history"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    problem_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("problems.id", ondelete="SET NULL"), nullable=True
    )
    user_input: Mapped[str] = mapped_column(Text, nullable=True)
    asr_text: Mapped[str] = mapped_column(Text, nullable=True)
    audio_url: Mapped[str] = mapped_column(Text, nullable=True)
    ai_feedback = mapped_column(JSONB, nullable=True)
    overall_score: Mapped[float] = mapped_column(Numeric(4, 2), nullable=True)
    match_similarity: Mapped[float] = mapped_column(Numeric(5, 4), nullable=True)
    elapsed_ms: Mapped[int] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=lambda: datetime.now(timezone.utc))

    user = relationship("User", back_populates="analyses")
    problem = relationship("Problem", back_populates="analyses")
    details = relationship("EvaluationDetail", back_populates="history", cascade="all, delete-orphan")


class EvaluationDetail(Base):
    __tablename__ = "evaluation_details"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    history_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("analysis_history.id", ondelete="CASCADE"), nullable=False
    )
    criteria_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("evaluation_criteria.id", ondelete="RESTRICT"), nullable=False
    )
    score: Mapped[float] = mapped_column(Numeric(4, 1), nullable=False)
    comment: Mapped[str] = mapped_column(Text, nullable=True)
    suggestion: Mapped[str] = mapped_column(Text, nullable=True)

    __table_args__ = (
        CheckConstraint("score >= 0 AND score <= 10", name="chk_score_range"),
    )

    history = relationship("AnalysisHistory", back_populates="details")
    criteria = relationship("EvaluationCriteria", back_populates="details")
