"""RAG 检索模块：用户输入 → BGE Embedding → pgvector 余弦相似度 → 匹配题目"""
import logging

import numpy as np
import psycopg
from sentence_transformers import SentenceTransformer

from app.config import settings

logger = logging.getLogger(__name__)

EMBEDDING_MODEL = "BAAI/bge-base-zh-v1.5"
SIMILARITY_THRESHOLD = 0.35  # 低于此阈值视为不匹配


class Retriever:
    def __init__(self):
        self.model: SentenceTransformer = None
        self._load_model()

    def _load_model(self):
        if self.model is not None:
            return
        logger.info(f"Loading embedding model: {EMBEDDING_MODEL}")
        self.model = SentenceTransformer(EMBEDDING_MODEL)
        logger.info("Embedding model loaded")

    def _get_conn(self):
        return psycopg.connect(settings.DATABASE_URL)

    def embed(self, text: str) -> list[float]:
        self._load_model()
        embedding = self.model.encode(
            text, normalize_embeddings=True, show_progress_bar=False
        )
        return embedding.tolist()

    def search(self, user_text: str, top_k: int = 3) -> dict:
        """检索最匹配的题目，返回完整信息 + 相似度"""
        embedding = self.embed(user_text)
        embedding_str = f"[{','.join(str(v) for v in embedding)}]"

        conn = self._get_conn()
        try:
            cur = conn.cursor()
            cur.execute(
                """
                SELECT id, title, difficulty, tags, description_cn,
                       solution_approach, solution_code,
                       complexity_time, complexity_space,
                       key_points, common_mistakes,
                       1 - (embedding <=> %s::vector) AS similarity
                FROM problems
                ORDER BY embedding <=> %s::vector
                LIMIT %s
                """,
                (embedding_str, embedding_str, top_k),
            )
            rows = cur.fetchall()
            cur.close()
        finally:
            conn.close()

        results = []
        for row in rows:
            results.append(
                {
                    "id": str(row[0]),
                    "title": row[1],
                    "difficulty": row[2],
                    "tags": row[3],
                    "description_cn": row[4],
                    "solution_approach": row[5],
                    "solution_code": row[6],
                    "complexity_time": row[7],
                    "complexity_space": row[8],
                    "key_points": row[9],
                    "common_mistakes": row[10],
                    "similarity": round(float(row[11]), 4),
                }
            )

        best = results[0] if results else None
        if best and best["similarity"] >= SIMILARITY_THRESHOLD:
            return {"matched": True, "problem": best, "candidates": results}
        else:
            return {"matched": False, "problem": None, "candidates": results}


retriever = Retriever()
