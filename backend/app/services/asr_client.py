"""ASR 客户端：Qwen3-ASR-Flash (DashScope) + SenseVoice (本地，预留)"""
import base64
import logging
import os
import mimetypes

import httpx

from app.config import settings

logger = logging.getLogger(__name__)

# qwen3-asr-flash uses OpenAI-compatible endpoint (chat/completions with input_audio)
ASR_BASE_URL = "https://dashscope.aliyuncs.com/compatible-mode/v1"


class QwenASRClient:
    """Qwen3-ASR-Flash via DashScope OpenAI-compatible API"""

    def __init__(self):
        self.api_key = settings.BAILIAN_ASR_API_KEY
        self.configured = bool(self.api_key and not self.api_key.startswith("your-"))

    async def transcribe(self, audio_path: str) -> str:
        if not self.configured:
            raise RuntimeError("DashScope API Key not configured")

        ext = os.path.splitext(audio_path)[1].lower()
        mime_type = mimetypes.guess_type(audio_path)[0] or "audio/mpeg"
        if ext == ".m4a":
            mime_type = "audio/mp4"
        elif ext == ".webm":
            mime_type = "audio/webm"

        with open(audio_path, "rb") as f:
            audio_b64 = base64.b64encode(f.read()).decode("utf-8")

        data_url = f"data:{mime_type};base64,{audio_b64}"

        request_body = {
            "model": settings.BAILIAN_ASR_MODEL,
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {
                            "type": "input_audio",
                            "input_audio": {"data": data_url},
                        }
                    ],
                }
            ],
        }

        url = f"{ASR_BASE_URL}/chat/completions"
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json=request_body,
            )

            if response.status_code != 200:
                logger.error(f"ASR API error: {response.status_code} {response.text[:300]}")
                raise RuntimeError(f"ASR transcription failed: HTTP {response.status_code}")

            result = response.json()
            choices = result.get("choices", [])
            if choices:
                text = choices[0].get("message", {}).get("content", "")
            else:
                text = ""
            if not text:
                logger.warning(f"ASR returned empty text. Response: {response.text[:300]}")
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
                "No ASR service available. Set BAILIAN_API_KEY in .env to enable Qwen3-ASR-Flash."
            )


asr_client = ASRClient()
