"""Test LLM and ASR clients"""
import os
import sys
import asyncio

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from dotenv import load_dotenv
load_dotenv(os.path.join(os.path.dirname(__file__), "..", "..", ".env"))


def test_deepseek_chat():
    """Test DeepSeek basic chat completion"""
    from app.services.llm_client import llm_client

    async def _run():
        response = await llm_client.chat_completion(
            messages=[
                {"role": "system", "content": "You are an algorithm interview coach."},
                {"role": "user", "content": "Explain hash table in one sentence."},
            ],
            max_tokens=200,
        )
        assert len(response) > 10, f"Response too short: {len(response)} chars"
        return response

    response = asyncio.run(_run())
    print(f"  Response: {response[:100]}...")
    print("  [PASS] DeepSeek chat completion")


def test_deepseek_stream():
    """Test DeepSeek streaming output"""
    from app.services.llm_client import llm_client

    async def _run():
        chunks = []
        async for chunk in llm_client.chat_completion_stream(
            messages=[
                {"role": "user", "content": "List 3 sorting algorithms in one sentence each."},
            ],
            max_tokens=300,
        ):
            chunks.append(chunk)
        full = "".join(chunks)
        assert len(full) > 20, f"Stream response too short: {len(full)} chars"
        return full

    response = asyncio.run(_run())
    print(f"  Response: {response[:100]}...")
    print("  [PASS] DeepSeek streaming")


def test_fallback_config():
    """Test fallback configuration"""
    from app.config import settings

    if settings.ZHIPU_API_KEY and not settings.ZHIPU_API_KEY.startswith("your-"):
        print(f"  GLM fallback: configured (model={settings.ZHIPU_MODEL})")
    else:
        print("  GLM fallback: not configured (using DeepSeek only)")
    print(f"  Primary LLM: {settings.DEEPSEEK_MODEL}")
    print("  [PASS] Fallback config check")


def test_asr_config():
    """Test ASR service configuration"""
    from app.services.asr_client import asr_client

    if asr_client.qwen.configured:
        print("  Qwen3-ASR-Flash: configured")
    else:
        print("  Qwen3-ASR-Flash: not configured (needs DASHSCOPE_API_KEY)")
    print("  SenseVoice: reserved for future local integration")
    print("  [PASS] ASR config check")


if __name__ == "__main__":
    api_key = os.getenv("DEEPSEEK_API_KEY", "")
    if not api_key or api_key.startswith("sk-your"):
        print("ERROR: DEEPSEEK_API_KEY not configured in .env")
        sys.exit(1)

    tests = [
        ("DeepSeek Chat", test_deepseek_chat),
        ("DeepSeek Stream", test_deepseek_stream),
        ("Fallback Config", test_fallback_config),
        ("ASR Config", test_asr_config),
    ]

    passed = 0
    failed = 0
    for name, fn in tests:
        print(f"\n{'='*60}")
        print(f"Test: {name}")
        print(f"{'='*60}")
        try:
            fn()
            passed += 1
        except Exception as e:
            print(f"  [FAIL] {e}")
            failed += 1

    print(f"\n{'='*60}")
    print(f"Results: {passed}/{len(tests)} passed, {failed} failed")
    print(f"{'='*60}")
