"""题目列表与详情路由"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Problem

router = APIRouter(prefix="/api/v1/problems", tags=["problems"])


@router.get("")
def list_problems(
    difficulty: str = Query(None, description="easy | medium | hard"),
    tag: str = Query(None, description="标签筛选"),
    db: Session = Depends(get_db),
):
    q = db.query(Problem)
    if difficulty:
        q = q.filter(Problem.difficulty == difficulty)
    if tag:
        q = q.filter(Problem.tags.any(tag))
    rows = q.order_by(Problem.title).all()
    return [
        {
            "id": str(r.id),
            "title": r.title,
            "difficulty": r.difficulty,
            "tags": r.tags or [],
        }
        for r in rows
    ]


@router.get("/{problem_id}")
def get_problem(problem_id: str, db: Session = Depends(get_db)):
    p = db.query(Problem).filter(Problem.id == problem_id).first()
    if not p:
        return {"error": "not found"}, 404
    return {
        "id": str(p.id),
        "title": p.title,
        "difficulty": p.difficulty,
        "tags": p.tags or [],
        "description_cn": p.description_cn,
        "solution_approach": p.solution_approach,
        "solution_code": p.solution_code,
        "complexity_time": p.complexity_time,
        "complexity_space": p.complexity_space,
        "key_points": p.key_points or [],
        "common_mistakes": p.common_mistakes or [],
    }
