"""题目列表与详情路由 — M:N 标签"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session, joinedload

from app.database import get_db
from app.models import Problem, ProblemTag, Tag

router = APIRouter(prefix="/api/v1/problems", tags=["problems"])


def _to_dict(p: Problem) -> dict:
    return {
        "id": str(p.id),
        "title": p.title,
        "title_cn": p.title_cn,
        "difficulty": p.difficulty,
        "tags": [tl.tag.name for tl in p.tag_links] if p.tag_links else [],
        "description_cn": p.description_cn,
        "solution_approach": p.solution_approach,
        "solution_code": p.solution_code,
        "complexity_time": p.complexity_time,
        "complexity_space": p.complexity_space,
        "key_points": p.key_points or [],
        "common_mistakes": p.common_mistakes or [],
    }


@router.get("")
def list_problems(
    difficulty: str = Query(None),
    tag: str = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(Problem).options(joinedload(Problem.tag_links).joinedload(ProblemTag.tag))
    if difficulty:
        q = q.filter(Problem.difficulty == difficulty)
    if tag:
        q = q.join(Problem.tag_links).join(ProblemTag.tag).filter(Tag.name == tag)
    rows = q.order_by(Problem.title).all()
    return [_to_dict(r) for r in rows]


@router.get("/{problem_id}")
def get_problem(problem_id: str, db: Session = Depends(get_db)):
    p = (
        db.query(Problem)
        .options(joinedload(Problem.tag_links).joinedload(ProblemTag.tag))
        .filter(Problem.id == problem_id)
        .first()
    )
    if not p:
        return {"error": "not found"}, 404
    return _to_dict(p)
