import os
from dotenv import load_dotenv

load_dotenv()


class Settings:
    # LLM
    DEEPSEEK_API_KEY: str = os.getenv("DEEPSEEK_API_KEY", "")
    DEEPSEEK_BASE_URL: str = os.getenv("DEEPSEEK_BASE_URL", "https://api.deepseek.com")
    DEEPSEEK_MODEL: str = os.getenv("DEEPSEEK_MODEL", "deepseek-chat")

    # GLM fallback LLM（智谱/Zhipu 或 阿里云百炼）
    BAILIAN_API_KEY: str = os.getenv("BAILIAN_API_KEY", "") or os.getenv("ZHIPU_API_KEY", "")
    BAILIAN_LLM_BASE_URL: str = os.getenv(
        "BAILIAN_LLM_BASE_URL", ""
    ) or os.getenv("ZHIPU_BASE_URL", "https://dashscope.aliyuncs.com/compatible-mode/v1")
    BAILIAN_LLM_MODEL: str = os.getenv("BAILIAN_LLM_MODEL", "") or os.getenv("ZHIPU_MODEL", "glm-5.1")

    # ASR（DashScope / 阿里云百炼）
    BAILIAN_ASR_API_KEY: str = os.getenv("DASHSCOPE_API_KEY", "") or os.getenv("BAILIAN_ASR_API_KEY", "")
    BAILIAN_ASR_BASE_URL: str = os.getenv("DASHSCOPE_BASE_URL", "") or os.getenv("BAILIAN_ASR_BASE_URL", "https://dashscope.aliyuncs.com/api/v1")
    BAILIAN_ASR_MODEL: str = os.getenv("BAILIAN_ASR_MODEL", "qwen3-asr-flash")

    # ASR — SenseVoice (local model, future)
    SENSEVOICE_MODEL_PATH: str = os.getenv("SENSEVOICE_MODEL_PATH", "")

    # Database
    DATABASE_URL: str = os.getenv(
        "DATABASE_URL", "postgresql+psycopg://postgres:postgres@localhost:5432/code2offer"
    )

    # Monitoring
    SENTRY_DSN: str = os.getenv("SENTRY_DSN", "")


settings = Settings()
