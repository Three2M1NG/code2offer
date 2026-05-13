"""Prompt quality evaluation: 5 test cases (Chinese input, English output)"""
import asyncio
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.services.prompt_manager import prompt_manager
from app.services.llm_client import llm_client

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

TEST_CASES = [
    {
        "id": 1,
        "category": "Correct answer",
        "problem_index": 0,
        "user_text": "使用哈希表，遍历数组中的每个元素。对于当前元素 nums[i]，计算 target - nums[i]，检查这个差值是否已经在哈希表中。如果在，说明找到了两个数之和等于 target，返回它们的下标。如果不在，将当前元素的值和下标存入哈希表。时间复杂度 O(n)，空间复杂度 O(n)。边界情况：如果数组为空或长度小于 2，直接返回空列表。题目保证有唯一解所以不考虑无解情况。",
    },
    {
        "id": 2,
        "category": "Right idea, wrong complexity",
        "problem_index": 4,
        "user_text": "用动态规划。dp[i] 表示以 nums[i] 结尾的最大子数组和。dp[i] = max(nums[i], dp[i-1] + nums[i])，最后答案取所有 dp 的最大值。时间复杂度 O(n)，空间复杂度 O(n)。",
    },
    {
        "id": 3,
        "category": "Brute force (suboptimal)",
        "problem_index": 5,
        "user_text": "三层循环嵌套。第一层 i 从 0 到 n-3，第二层 j 从 i+1 到 n-2，第三层 k 从 j+1 到 n-1。如果 nums[i]+nums[j]+nums[k]==0 就把这个三元组加到结果里。时间复杂度 O(n^3)，空间复杂度 O(1)。",
    },
    {
        "id": 4,
        "category": "Completely wrong",
        "problem_index": 3,
        "user_text": "贪心算法，每一天如果价格比后一天低就买入，比后一天高就卖出，累加所有利润得到最大总收益。时间复杂度 O(n)，空间复杂度 O(1)。",
    },
    {
        "id": 5,
        "category": "Too brief / incomplete",
        "problem_index": 7,
        "user_text": "BFS。用队列。",
    },
]


async def evaluate_case(case, problems):
    problem = problems[case["problem_index"]]
    messages = prompt_manager.build_messages(
        user_text=case["user_text"],
        problem_description=problem["description_cn"],
        standard_solution=problem["solution_approach"],
    )
    response = await llm_client.chat_completion(
        messages=messages, temperature=0.3, max_tokens=2048
    )
    json_match = re.search(r"\{[\s\S]*\}", response)
    result = None
    error = None
    if json_match:
        try:
            result = json.loads(json_match.group())
        except json.JSONDecodeError as e:
            error = str(e)
    return {
        "case_id": case["id"],
        "category": case["category"],
        "problem": problem["title"],
        "parsed": result,
        "parse_error": error,
        "response_preview": response[:300],
    }


async def main():
    data_path = os.path.join(BASE_DIR, "data", "problems.json")
    with open(data_path, "r", encoding="utf-8") as f:
        problems = json.load(f)

    print("=" * 60)
    print("Prompt v1 Evaluation - 5 Test Cases")
    print("=" * 60)

    results = []
    for i, case in enumerate(TEST_CASES):
        print(f"\n[{i+1}/5] {case['category']} ({problems[case['problem_index']]['title']})...")
        result = await evaluate_case(case, problems)
        results.append(result)

    print("\n" + "=" * 60)
    print("Results")
    print("=" * 60)

    all_valid = True
    for r in results:
        title = problems[TEST_CASES[r["case_id"] - 1]["problem_index"]]["title"]
        print(f"\nCase {r['case_id']}: {r['category']} | {title}")
        if r["parsed"]:
            p = r["parsed"]
            print(f"  Overall: {p['overall_score']}")
            for d in p["dimensions"]:
                bar = "#" * d["score"] + "-" * (10 - d["score"])
                print(f"  [{bar}] {d['name']}: {d['score']}/10")
            summary = p['summary'][:120].replace('\n', ' ')
            print(f"  Summary: {summary}")
        else:
            all_valid = False
            print(f"  [JSON ERROR] {r['parse_error']}")
            print(f"  Preview: {r['response_preview'][:200]}")

    print("\n" + "=" * 60)
    if all_valid:
        print("[PASS] All 5/5 valid JSON")
    else:
        print("[WARN] JSON parsing issues found")
    print("=" * 60)


if __name__ == "__main__":
    asyncio.run(main())
