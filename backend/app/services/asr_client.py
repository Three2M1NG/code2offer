"""ASR 客户端：Qwen3-ASR-Flash (DashScope) + SenseVoice (本地，预留)"""
import base64
import logging
import os

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class QwenASRClient:
    """Qwen3-ASR-Flash via DashScope API"""

    def __init__(self):
        self.api_key = settings.DASHSCOPE_API_KEY
        self.base_url = settings.DASHSCOPE_BASE_URL
        self.configured = bool(self.api_key and not self.api_key.startswith("your-"))

    async def transcribe(self, audio_path: str) -> str:
        """将音频文件转写为文本"""
        if not self.configured:
            raise RuntimeError("DashScope API Key not configured")

        # DashScope ASR endpoint for Qwen3-ASR-Flash
        url = f"{self.base_url}/services/audio/asr/transcription"

        # Read audio file and encode as base64
        with open(audio_path, "rb") as f:
            audio_data = base64.b64encode(f.read()).decode("utf-8")

        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": "qwen3-asr-flash",
                    "input": {"audio": audio_data},
                },
            )

            if response.status_code != 200:
                logger.error(f"ASR API error: {response.status_code} {response.text[:200]}")
                raise RuntimeError(f"ASR transcription failed: HTTP {response.status_code}")

            result = response.json()
            text = result.get("output", {}).get("text", "")
            if not text:
                logger.warning(f"ASR returned empty text. Response: {response.text[:200]}")
            return text


class SenseVoiceASRClient:
    """SenseVoice 本地模型（后续集成）"""

    def __init__(self):
        self.model = None

    async def transcribe(self, audio_path: str) -> str:
        raise NotImplementedError("SenseVoice not yet integrated. Use Qwen3-ASR-Flash.")


class ASRClient:
    """ASR 统一接口：Qwen3-ASR-Flash 优先 → SenseVoice fallback"""

    def __init__(self):
        self.qwen = QwenASRClient()
        self.sensevoice = SenseVoiceASRClient()

    async def transcribe(self, audio_path: str) -> str:
        if self.qwen.configured:
            try:
                return await self.qwen.transcribe(audio_path)
            except Exception as e:
                logger.warning(f"Qwen3-ASR-Flash failed: {e}, trying SenseVoice")
        try:
            return await self.sensevoice.transcribe(audio_path)
        except NotImplementedError:
            raise RuntimeError(
                "No ASR service available. Set DASHSCOPE_API_KEY for Qwen3-ASR-Flash."
            )


asr_client = ASRClient()
