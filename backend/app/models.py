import uuid
from datetime import datetime, timezone

from pgvector.sqlalchemy import Vector
from sqlalchemy import String, Text, DateTime, ForeignKey, CheckConstraint
from sqlalchemy.dialects.postgresql import ARRAY, UUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Problem(Base):
    __tablename__ = "problems"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    difficulty: Mapped[str] = mapped_column(String(10), nullable=False)
    tags = mapped_column(ARRAY(String))
    description_cn: Mapped[str] = mapped_column(Text, nullable=True)
    solution_approach: Mapped[str] = mapped_column(Text, nullable=True)
    solution_code: Mapped[str] = mapped_column(Text, nullable=True)
    complexity_time: Mapped[str] = mapped_column(String(50), nullable=True)
    complexity_space: Mapped[str] = mapped_column(String(50), nullable=True)
    key_points = mapped_column(ARRAY(String))
    common_mistakes = mapped_column(ARRAY(String))
    embedding = mapped_column(Vector(768), nullable=True)

    __table_args__ = (
        CheckConstraint("difficulty IN ('easy', 'medium', 'hard')", name="chk_difficulty"),
    )


class AnalysisHistory(Base):
    __tablename__ = "analysis_history"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    problem_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("problems.id"), nullable=True
    )
    user_input: Mapped[str] = mapped_column(Text, nullable=True)
    asr_text: Mapped[str] = mapped_column(Text, nullable=True)
    ai_feedback = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
