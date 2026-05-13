"""Prompt 模板管理器：加载、版本管理、占位符填充"""
import os
from pathlib import Path


class PromptManager:
    """管理 Prompt 模板的加载与版本切换"""

    def __init__(self, prompts_dir: str = None):
        if prompts_dir is None:
            # Walk up from this file to project root, then into prompts/
            current = Path(__file__).resolve().parent
            while current.name not in ("", "code2offer") and current.parent != current:
                if (current / "prompts").is_dir():
                    prompts_dir = current / "prompts"
                    break
                current = current.parent
            else:
                prompts_dir = current / "prompts"
        self.prompts_dir = Path(prompts_dir)
        self._cache = {}

    def list_versions(self) -> list[str]:
        return sorted(
            [f.stem for f in self.prompts_dir.glob("v*.txt")],
            key=lambda v: int(v[1:]) if v[1:].isdigit() else 0,
        )

    def latest_version(self) -> str:
        versions = self.list_versions()
        return versions[-1] if versions else "v1"

    def load(self, version: str = None) -> str:
        version = version or self.latest_version()
        if version in self._cache:
            return self._cache[version]

        path = self.prompts_dir / f"{version}.txt"
        if not path.exists():
            raise FileNotFoundError(f"Prompt 模板不存在: {path}")

        template = path.read_text(encoding="utf-8")
        self._cache[version] = template
        return template

    def build_messages(
        self,
        user_text: str,
        problem_description: str,
        standard_solution: str,
        version: str = None,
    ) -> list[dict]:
        """组装完整的 messages 列表，可直接发送给 LLM"""
        template = self.load(version)

        system_prompt = (
            template
            .replace("<<<PROBLEM_DESCRIPTION>>>", problem_description)
            .replace("<<<STANDARD_SOLUTION>>>", standard_solution)
            .replace("<<<USER_TEXT>>>", user_text)
        )

        return [
            {"role": "system", "content": system_prompt},
        ]

    def build_analysis_prompt(
        self,
        user_text: str,
        problem_description: str,
        standard_solution: str,
        version: str = None,
    ) -> str:
        """返回填充后的完整 prompt 字符串"""
        template = self.load(version)
        return (
            template
            .replace("<<<PROBLEM_DESCRIPTION>>>", problem_description)
            .replace("<<<STANDARD_SOLUTION>>>", standard_solution)
            .replace("<<<USER_TEXT>>>", user_text)
        )


prompt_manager = PromptManager()
