"""判卷路由：文本/音频 → RAG 检索 → LLM 流式评价 → SSE 返回"""
import json
import logging
import os
import re
import tempfile
import time
import uuid

from fastapi import APIRouter, Request, UploadFile, File, Form
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from app.services.retriever import retriever
from app.services.prompt_manager import prompt_manager
from app.services.llm_client import llm_client
from app.services.asr_client import asr_client

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/v1", tags=["analyze"])


class AnalyzeRequest(BaseModel):
    text: str
    problem_id: str = None


async def _stream_analysis(user_text: str, request_id: str):
    """SSE 流式返回 AI 评价，含完整异常处理"""
    t_start = time.time()

    # Step 1: RAG 检索
    try:
        search_result = retriever.search(user_text)
    except Exception as e:
        logger.error(f"[{request_id}] RAG search failed: {e}")
        yield f"event: error\ndata: {json.dumps({'error': '题目检索失败，请重试'}, ensure_ascii=False)}\n\n"
        return

    problem = search_result.get("problem")
    matched = search_result.get("matched", False)

    if not matched or not problem:
        yield f"event: info\ndata: {json.dumps({'matched': False, 'message': '未匹配到具体题目，请描述你正在解答的算法题'}, ensure_ascii=False)}\n\n"
        return

    yield f"event: match\ndata: {json.dumps({'matched': True, 'problem': problem['title'], 'difficulty': problem['difficulty'], 'similarity': problem['similarity']}, ensure_ascii=False)}\n\n"

    # Step 2: 组装 Prompt
    try:
        messages = prompt_manager.build_messages(
            user_text=user_text,
            problem_description=problem["description_cn"] or "",
            standard_solution=problem["solution_approach"] or "",
        )
    except Exception as e:
        logger.error(f"[{request_id}] Prompt build failed: {e}")
        yield f"event: error\ndata: {json.dumps({'error': '系统错误'}, ensure_ascii=False)}\n\n"
        return

    # Step 3: LLM 流式生成
    full_response = ""
    try:
        async for chunk in llm_client.chat_completion_stream(
            messages=messages, temperature=0.3, max_tokens=2048
        ):
            full_response += chunk
            yield f"event: chunk\ndata: {json.dumps({'content': chunk}, ensure_ascii=False)}\n\n"
    except RuntimeError as e:
        logger.error(f"[{request_id}] All LLMs failed: {e}")
        yield f"event: error\ndata: {json.dumps({'error': 'AI 服务暂时不可用，请稍后重试'}, ensure_ascii=False)}\n\n"
        return

    # Step 4: 解析结构化结果
    json_match = re.search(r"\{[\s\S]*\}", full_response)
    if json_match:
        try:
            result = json.loads(json_match.group())
            elapsed = int((time.time() - t_start) * 1000)
            for dim in result.get("dimensions", []):
                yield f"event: dimension\ndata: {json.dumps(dim, ensure_ascii=False)}\n\n"
            done_data = json.dumps({
                "overall_score": result.get("overall_score"),
                "summary": result.get("summary", ""),
                "reference_answer": result.get("reference_answer", {}),
                "elapsed_ms": elapsed,
            }, ensure_ascii=False)
            yield f"event: done\ndata: {done_data}\n\n"
            logger.info(f"[{request_id}] Analysis complete in {elapsed}ms, score={result.get('overall_score')}")
            return
        except json.JSONDecodeError:
            logger.warning(f"[{request_id}] JSON parse failed, returning raw")

    yield f"event: done\ndata: {json.dumps({'raw': full_response, 'elapsed_ms': int((time.time() - t_start) * 1000)}, ensure_ascii=False)}\n\n"


@router.post("/analyze")
async def analyze_text(request: AnalyzeRequest):
    """文本模式判卷（SSE 流式返回）"""
    text = (request.text or "").strip()
    if len(text) < 3:
        return {"error": "请输入至少 3 个字的解题思路"}, 400

    return StreamingResponse(
        _stream_analysis(text, str(uuid.uuid4())[:8]),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",
        },
    )


@router.post("/transcribe")
async def transcribe_audio(file: UploadFile = File(...)):
    """仅语音转文本，不触发判卷"""
    if not file.filename:
        return {"error": "请上传音频文件"}, 400

    allowed = {".wav", ".mp3", ".m4a", ".webm", ".ogg", ".flac"}
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in allowed:
        return {"error": f"不支持的音频格式: {ext}"}, 400

    with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        text = await asr_client.transcribe(tmp_path)
        if not text or len(text.strip()) < 2:
            return {"error": "语音识别结果过短，请重新录制"}, 400
        return {"text": text.strip()}
    except RuntimeError as e:
        logger.error(f"Transcribe failed: {e}")
        return {"error": "语音识别服务不可用"}, 503
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


@router.post("/analyze/audio")
async def analyze_audio(
    file: UploadFile = File(...),
    problem_id: str = Form(None),
):
    """音频模式判卷：上传音频 → ASR 转写 → 文本判卷"""
    if not file.filename:
        return {"error": "请上传音频文件"}, 400

    # 检查文件格式
    allowed = {".wav", ".mp3", ".m4a", ".webm", ".ogg", ".flac"}
    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in allowed:
        return {"error": f"不支持的音频格式: {ext}，支持: {', '.join(allowed)}"}, 400

    request_id = str(uuid.uuid4())[:8]

    # 保存临时文件
    with tempfile.NamedTemporaryFile(delete=False, suffix=ext) as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name

    try:
        # ASR 转写
        logger.info(f"[{request_id}] Transcribing audio: {file.filename} ({len(content)} bytes)")
        text = await asr_client.transcribe(tmp_path)
        if not text or len(text.strip()) < 3:
            return {"error": "语音识别结果过短，请重新录制"}, 400

        logger.info(f"[{request_id}] ASR result: {text[:100]}...")

        # 文本判卷（复用 SSE 流）
        return StreamingResponse(
            _stream_analysis(text, request_id),
            media_type="text/event-stream",
            headers={
                "Cache-Control": "no-cache",
                "Connection": "keep-alive",
                "X-Accel-Buffering": "no",
            },
        )
    except RuntimeError as e:
        logger.error(f"[{request_id}] ASR failed: {e}")
        return {"error": "语音识别服务不可用，请使用文本输入或稍后重试"}, 503
    finally:
        # 清理临时文件
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
