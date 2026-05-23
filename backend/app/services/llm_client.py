"""LLM 客户端：DeepSeek V4 Pro 主力 + GLM-5.1 fallback"""
import logging
from typing import AsyncGenerator

from openai import AsyncOpenAI

from app.config import settings

logger = logging.getLogger(__name__)


class LLMClient:
    """统一 LLM 调用接口，内置 DeepSeek → GLM fallback"""

    def __init__(self):
        self.primary = AsyncOpenAI(
            api_key=settings.DEEPSEEK_API_KEY,
            base_url=f"{settings.DEEPSEEK_BASE_URL}/v1",
            timeout=60.0,
            max_retries=2,
        )
        self.primary_model = settings.DEEPSEEK_MODEL

        self.fallback = None
        if settings.BAILIAN_API_KEY and not settings.BAILIAN_API_KEY.startswith("your-"):
            self.fallback = AsyncOpenAI(
                api_key=settings.BAILIAN_API_KEY,
                base_url=settings.BAILIAN_LLM_BASE_URL,
                timeout=60.0,
                max_retries=2,
            )
            self.fallback_model = settings.BAILIAN_LLM_MODEL
        else:
            logger.info("百炼 fallback 未配置，将仅使用 DeepSeek")

    async def chat_completion(
        self,
        messages: list[dict],
        stream: bool = False,
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> str:
        """发送对话请求，返回完整响应文本"""
        last_error = None
        for attempt, (client, model) in enumerate(self._clients()):
            try:
                response = await client.chat.completions.create(
                    model=model,
                    messages=messages,
                    stream=False,
                    temperature=temperature,
                    max_tokens=max_tokens,
                )
                return response.choices[0].message.content or ""
            except Exception as e:
                last_error = e
                logger.warning(f"[{model}] 第 {attempt+1} 次尝试失败: {e}")
                if attempt == 0:
                    logger.info("切换到 fallback LLM...")
        raise RuntimeError(f"所有 LLM 调用均失败: {last_error}")

    async def chat_completion_stream(
        self,
        messages: list[dict],
        temperature: float = 0.7,
        max_tokens: int = 2048,
    ) -> AsyncGenerator[str, None]:
        """流式对话，逐 chunk 返回文本增量"""
        last_error = None
        for attempt, (client, model) in enumerate(self._clients()):
            try:
                stream = await client.chat.completions.create(
                    model=model,
                    messages=messages,
                    stream=True,
                    temperature=temperature,
                    max_tokens=max_tokens,
                )
                async for chunk in stream:
                    delta = chunk.choices[0].delta
                    if delta and delta.content:
                        yield delta.content
                return
            except Exception as e:
                last_error = e
                logger.warning(f"[{model}] 流式第 {attempt+1} 次尝试失败: {e}")
        raise RuntimeError(f"所有 LLM 流式调用均失败: {last_error}")

    def _clients(self):
        """按优先级返回 (client, model_name) 对"""
        yield (self.primary, self.primary_model)
        if self.fallback:
            yield (self.fallback, self.fallback_model)


llm_client = LLMClient()
