"""ASR 客户端：Qwen3-ASR-Flash (DashScope) + SenseVoice (本地模型，预留)"""
import logging
import os
import tempfile

import httpx

from app.config import settings

logger = logging.getLogger(__name__)


class QwenASRClient:
    """Qwen3-ASR-Flash via DashScope API"""

    def __init__(self):
        self.api_key = settings.DASHSCOPE_API_KEY
        self.base_url = settings.DASHSCOPE_BASE_URL
        self.model = "qwen3-asr-flash"
        self.configured = bool(self.api_key and not self.api_key.startswith("your-"))

    async def transcribe(self, audio_path: str) -> str:
        """将音频文件转写为文本"""
        if not self.configured:
            raise RuntimeError("DashScope API Key 未配置，请设置 DASHSCOPE_API_KEY")

        url = f"{self.base_url}/services/aigc/multimodal-generation/generation"
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                url,
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                },
                json={
                    "model": self.model,
                    "input": {"messages": [{"role": "user", "content": []}]},
                    "parameters": {},
                },
            )
            response.raise_for_status()
            return response.text


class SenseVoiceASRClient:
    """SenseVoice 本地模型（后续集成）"""

    def __init__(self):
        self.model = None
        self.model_path = settings.SENSEVOICE_MODEL_PATH

    def _load_model(self):
        if self.model is not None:
            return
        logger.info("加载 SenseVoice 本地模型...")
        # TODO: 后续接入 funasr 的 SenseVoice 模型
        # from funasr import AutoModel
        # self.model = AutoModel(model=self.model_path or "iic/SenseVoiceSmall")
        raise NotImplementedError("SenseVoice 本地模型尚未集成，请使用 Qwen3-ASR-Flash")

    async def transcribe(self, audio_path: str) -> str:
        self._load_model()
        # TODO: result = self.model.generate(input=audio_path)
        raise NotImplementedError("SenseVoice 尚未实现")


class ASRClient:
    """ASR 统一接口：Qwen3-ASR-Flash → SenseVoice fallback"""

    def __init__(self):
        self.qwen = QwenASRClient()
        self.sensevoice = SenseVoiceASRClient()

    async def transcribe(self, audio_path: str) -> str:
        """转写音频，Qwen3-ASR-Flash 优先"""
        if self.qwen.configured:
            try:
                return await self.qwen.transcribe(audio_path)
            except Exception as e:
                logger.warning(f"Qwen3-ASR-Flash 失败: {e}，降级到 SenseVoice")

        try:
            return await self.sensevoice.transcribe(audio_path)
        except NotImplementedError:
            raise RuntimeError(
                "没有可用的 ASR 服务。请设置 DASHSCOPE_API_KEY 以使用 Qwen3-ASR-Flash"
            )


asr_client = ASRClient()
