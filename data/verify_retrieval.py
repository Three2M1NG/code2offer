"""检索验证脚本：自然语言查询 → Embedding → pgvector 余弦相似度检索 → 验证命中率"""
import os
import sys

import psycopg
import psycopg.rows
from dotenv import load_dotenv
from sentence_transformers import SentenceTransformer

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

DATABASE_URL = os.getenv(
    "DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/code2offer"
)

EMBEDDING_MODEL = "BAAI/bge-base-zh-v1.5"

# 测试用例：自然语言查询 → 预期命中的题目
TEST_CASES = [
    {
        "query": "在一个数组中找到两个数，使它们的和等于目标值，返回它们的下标",
        "expected_title": "Two Sum",
    },
    {
        "query": "判断一个包含括号的字符串是否合法，所有括号必须正确闭合",
        "expected_title": "Valid Parentheses",
    },
    {
        "query": "翻转一个单链表",
        "expected_title": "Reverse Linked List",
    },
    {
        "query": "股票买卖问题，只能买卖一次，求最大利润",
        "expected_title": "Best Time to Buy and Sell Stock",
    },
    {
        "query": "找到一个数组中的连续子数组使得和最大",
        "expected_title": "Maximum Subarray",
    },
    {
        "query": "三个数之和等于零的所有不重复三元组",
        "expected_title": "3Sum",
    },
    {
        "query": "找出一个字符串中最长的回文子串",
        "expected_title": "Longest Palindromic Substring",
    },
    {
        "query": "设计一个LRU缓存，支持O(1)时间复杂度的get和put操作",
        "expected_title": "LRU Cache",
    },
    {
        "query": "计算二维网格中岛屿的数量",
        "expected_title": "Number of Islands",
    },
    {
        "query": "用最少的硬币凑出目标金额",
        "expected_title": "Coin Change",
    },
]


def search(conn, embedding: list[float], top_k: int = 3) -> list[dict]:
    cur = conn.cursor(row_factory=psycopg.rows.dict_row)
    embedding_str = f"[{','.join(str(v) for v in embedding)}]"
    cur.execute(
        """
        SELECT title, difficulty, tags,
               1 - (embedding <=> %s::vector) AS similarity
        FROM problems
        ORDER BY embedding <=> %s::vector
        LIMIT %s
        """,
        (embedding_str, embedding_str, top_k),
    )
    results = cur.fetchall()
    cur.close()
    return results


def main():
    conn = psycopg2.connect(DATABASE_URL)

    print(f"加载 Embedding 模型: {EMBEDDING_MODEL}")
    model = SentenceTransformer(EMBEDDING_MODEL)

    print(f"{'='*70}")
    print(f"RAG 检索验证 — 共 {len(TEST_CASES)} 个测试用例")
    print(f"{'='*70}\n")

    hits_at_1 = 0
    hits_at_3 = 0

    queries = [tc["query"] for tc in TEST_CASES]
    embeddings = model.encode(queries, normalize_embeddings=True)

    for i, tc in enumerate(TEST_CASES):
        try:
            embedding = embeddings[i]
            results = search(conn, embedding, top_k=3)

            titles = [r["title"] for r in results]
            hit_1 = tc["expected_title"] == titles[0] if titles else False
            hit_3 = tc["expected_title"] in titles

            hits_at_1 += int(hit_1)
            hits_at_3 += int(hit_3)

            status = "<< " if hit_1 else ("<  " if hit_3 else "xx ")
            print(f"  [{i+1:2d}] {status} 查询: {tc['query'][:45]}...")
            print(f"       期望: {tc['expected_title']}")
            for j, r in enumerate(results):
                marker = " <-- HIT" if r["title"] == tc["expected_title"] else ""
                print(f"       Top-{j+1}: {r['title']:35s} (相似度: {r['similarity']:.4f}){marker}")
            print()

        except Exception as e:
            print(f"  [{i+1:2d}] !! 查询失败: {tc['query'][:45]}... | 错误: {e}\n")

    conn.close()

    precision_1 = hits_at_1 / len(TEST_CASES)
    precision_3 = hits_at_3 / len(TEST_CASES)

    print(f"{'='*70}")
    print(f"结果汇总")
    print(f"{'='*70}")
    print(f"  Precision@1: {hits_at_1}/{len(TEST_CASES)} = {precision_1:.1%}")
    print(f"  Precision@3: {hits_at_3}/{len(TEST_CASES)} = {precision_3:.1%}")
    print(f"  目标: Precision@3 > 0.7")
    if precision_3 >= 0.7:
        print(f"  [PASS] 检索质量达标！")
    else:
        print(f"  [FAIL] 检索质量未达标，需排查 Embedding 或数据质量")
    print(f"{'='*70}")


if __name__ == "__main__":
    main()
