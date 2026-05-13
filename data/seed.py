"""种子数据入库脚本：读取 problems.json → sentence-transformers Embedding → pgvector INSERT"""
import json
import os
import sys

import psycopg
from dotenv import load_dotenv
from sentence_transformers import SentenceTransformer

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/code2offer"
)

EMBEDDING_MODEL = "BAAI/bge-base-zh-v1.5"
BATCH_SIZE = 10


def load_problems(path: str) -> list[dict]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def seed():
    problems_path = os.path.join(os.path.dirname(__file__), "problems.json")
    problems = load_problems(problems_path)
    print(f"加载 {len(problems)} 道题目")

    print(f"加载 Embedding 模型: {EMBEDDING_MODEL}")
    model = SentenceTransformer(EMBEDDING_MODEL)

    conn = psycopg.connect(DATABASE_URL)
    conn.autocommit = True
    cur = conn.cursor()

    # 清空旧数据
    cur.execute("DELETE FROM analysis_history")
    cur.execute("DELETE FROM problems")
    print("已清空旧数据")

    # 批量生成 Embedding（标题+标签+描述+题解 组合用于更准检索）
    texts = [
        f"题目：{p['title']}\n标签：{', '.join(p['tags'])}\n描述：{p['description_cn'][:200]}\n题解：{p['solution_approach'][:300]}"
        for p in problems
    ]
    print(f"正在为 {len(texts)} 道题生成向量...")
    embeddings = model.encode(texts, show_progress_bar=True, normalize_embeddings=True)

    success = 0
    for i, problem in enumerate(problems):
        try:
            emb = embeddings[i]
            embedding_str = f"[{','.join(str(v) for v in emb)}]"

            cur.execute(
                """
                INSERT INTO problems
                    (title, difficulty, tags, description_cn,
                     solution_approach, solution_code, complexity_time,
                     complexity_space, key_points, common_mistakes, embedding)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s::vector)
                """,
                (
                    problem["title"],
                    problem["difficulty"],
                    problem["tags"],
                    problem["description_cn"],
                    problem["solution_approach"],
                    problem["solution_code"],
                    problem["complexity_time"],
                    problem["complexity_space"],
                    problem["key_points"],
                    problem["common_mistakes"],
                    embedding_str,
                ),
            )
            success += 1
            print(f"  [{i+1}/{len(problems)}] OK {problem['title']}")

        except Exception as e:
            print(f"  [{i+1}/{len(problems)}] FAIL {problem['title']}: {e}")

    cur.close()
    conn.close()

    print(f"\n入库完成: {success}/{len(problems)} 道题目成功")


if __name__ == "__main__":
    seed()
