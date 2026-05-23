"""种子数据入库脚本（M:N 架构）"""
import json
import os
import sys

import psycopg
from dotenv import load_dotenv
from sentence_transformers import SentenceTransformer

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/code2offer"
).replace("+psycopg", "")

EMBEDDING_MODEL = "BAAI/bge-base-zh-v1.5"

# 中文标签 → tags 表中的英文名称映射
TAG_MAP = {
    "数组": "Array",
    "哈希表": "Hash Table",
    "栈": "Stack",
    "字符串": "String",
    "链表": "Linked List",
    "迭代": "Iteration",
    "递归": "Recursion",
    "动态规划": "DP",
    "双指针": "Two Pointers",
    "排序": "Sorting",
    "BFS": "BFS",
    "队列": "Queue",
    "设计": "Design",
    "DFS": "DFS",
    "并查集": "Union Find",
    "矩阵": "Matrix",
    "背包": "Knapsack",
    "数学": "Math",
    "Trie": "Trie",
    "分治": "Divide and Conquer",
    "树": "Tree",
}


def load_problems(path: str) -> list[dict]:
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def seed():
    problems_path = os.path.join(os.path.dirname(__file__), "problems.json")
    problems = load_problems(problems_path)
    print(f"Loaded {len(problems)} problems")

    print(f"Loading embedding model: {EMBEDDING_MODEL}")
    model = SentenceTransformer(EMBEDDING_MODEL)

    conn = psycopg.connect(DATABASE_URL)
    conn.autocommit = True
    cur = conn.cursor()

    # 清空旧数据（按外键依赖顺序）
    cur.execute("DELETE FROM evaluation_details")
    cur.execute("DELETE FROM analysis_history")
    cur.execute("DELETE FROM problem_tags")
    cur.execute("DELETE FROM problems")
    print("Cleared old data")

    # 构建嵌入文本
    texts = [
        f"Title: {p['title']}\nTags: {', '.join(p['tags'])}\nDescription: {p['description_cn'][:200]}\nSolution: {p['solution_approach'][:300]}"
        for p in problems
    ]
    print(f"Generating vectors for {len(texts)} problems...")
    embeddings = model.encode(texts, show_progress_bar=True, normalize_embeddings=True)

    # 预加载标签字典: name → id
    cur.execute("SELECT name, id FROM tags")
    tag_name_to_id = {row[0]: row[1] for row in cur.fetchall()}
    print(f"Existing tags: {len(tag_name_to_id)}")

    success = 0
    missing_tags = set()

    for i, problem in enumerate(problems):
        try:
            emb = embeddings[i]
            embedding_str = f"[{','.join(str(v) for v in emb)}]"

            # Step 1: 插入 problems 表（无 tags 列）
            cur.execute(
                """
                INSERT INTO problems
                    (title, difficulty, description_cn,
                     solution_approach, solution_code, complexity_time,
                     complexity_space, key_points, common_mistakes, embedding)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s::vector)
                RETURNING id
                """,
                (
                    problem["title"],
                    problem["difficulty"],
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
            problem_id = cur.fetchone()[0]

            # Step 2: 处理标签 → problem_tags 关联表
            for cn_tag in problem["tags"]:
                en_tag = TAG_MAP.get(cn_tag, cn_tag)
                tag_id = tag_name_to_id.get(en_tag)
                if tag_id is None:
                    missing_tags.add(en_tag)
                    # 尝试动态插入
                    try:
                        cur.execute(
                            "INSERT INTO tags (name) VALUES (%s) ON CONFLICT (name) DO UPDATE SET name=EXCLUDED.name RETURNING id",
                            (en_tag,),
                        )
                        tag_id = cur.fetchone()[0]
                        tag_name_to_id[en_tag] = tag_id
                    except Exception as e:
                        print(f"  Failed to insert tag '{en_tag}': {e}")
                        continue

                cur.execute(
                    "INSERT INTO problem_tags (problem_id, tag_id) VALUES (%s, %s) ON CONFLICT DO NOTHING",
                    (problem_id, tag_id),
                )

            success += 1
            print(f"  [{i+1}/{len(problems)}] OK {problem['title']} [{', '.join(problem['tags'])}]")

        except Exception as e:
            print(f"  [{i+1}/{len(problems)}] FAIL {problem['title']}: {e}")

    if missing_tags:
        print(f"\nWarning: {len(missing_tags)} tags not found in tags table, auto-inserted")

    cur.close()
    conn.close()
    print(f"\nSeeding complete: {success}/{len(problems)} problems")


if __name__ == "__main__":
    seed()
