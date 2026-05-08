# code2offer

AI 算法面试教练 —— 收录 15 道高频 LeetCode 题，支持语音/文本输入解题思路，AI 流式返回五维度结构化评价。

## 架构

```
                    Flutter App (iOS/Android)
                           │
                    HTTPS / SSE stream
                           │
               ┌───────────▼────────────┐
               │    FastAPI 后端          │
               │  /api/v1/analyze        │
               │  /api/v1/problems       │
               │  /api/v1/health         │
               └──┬────────┬──────────┬──┘
                  │        │          │
         ┌────────▼──┐ ┌──▼────┐ ┌──▼──────────┐
         │ RAG 检索    │ │  LLM  │ │  ASR        │
         │ BGE-base   │ │ DeepSeek│ │ Qwen3-ASR  │
         │ pgvector   │ │  V4 Pro │ │  Flash      │
         └────────────┘ └──┬─────┘ └─────────────┘
                           │ fallback
                      ┌────▼─────┐
                      │ GLM-5.1  │
                      └──────────┘
```

**数据流：** 用户输入（文本/语音）→ ASR 转文本 → BGE Embedding → pgvector 检索匹配题目 → 组装 Prompt（用户思路 + 标准题解 + 题目描述）→ DeepSeek V4 Pro 流式评价 → SSE 返回客户端

## 技术栈

| 层 | 选型 |
|----|------|
| 客户端 | Flutter 3.x + Riverpod |
| 后端 | Python FastAPI + Uvicorn + SSE |
| 主力 LLM | DeepSeek V4 Pro（deepseek-chat） |
| 备用 LLM | GLM-5.1（智谱 API） |
| ASR | Qwen3-ASR-Flash（DashScope）→ SenseVoice（本地，后续） |
| Embedding | BAAI/bge-base-zh-v1.5（本地，768 维） |
| 向量库 | PostgreSQL 16 + pgvector |
| 部署 | Railway / Fly.io + GitHub Actions |

## 快速启动

```bash
# 1. 配置环境变量
cp .env.example .env
# 编辑 .env 填入 DeepSeek / Zhipu / DashScope API Keys

# 2. 启动数据库
docker compose up -d

# 3. 安装依赖
pip install -r backend/requirements.txt

# 4. 导入种子数据（15 道精选高频题）
cd data && python seed.py

# 5. 验证检索质量
python verify_retrieval.py

# 6. 启动后端
cd ../backend && uvicorn app.main:app --reload
# 浏览器打开 http://localhost:8000/docs 查看 Swagger

# 7. 启动 Flutter
cd ../client && flutter run
```

## API 端点

| Method | Path | 说明 |
|--------|------|------|
| GET | `/api/v1/health` | 健康检查 |
| GET | `/api/v1/problems` | 题目列表（`?difficulty=medium&tag=DP`） |
| GET | `/api/v1/problems/{id}` | 题目详情 |
| POST | `/api/v1/analyze` | 判卷（JSON 文本 / multipart 音频） |

## 项目结构

```
code2offer/
├── client/              # Flutter App
├── backend/
│   ├── app/
│   │   ├── main.py      # FastAPI 入口 + CORS + 路由
│   │   ├── config.py    # 环境变量配置
│   │   ├── database.py  # SQLAlchemy + pgvector 连接
│   │   ├── models.py    # ORM（Problem, AnalysisHistory）
│   │   ├── routers/     # API 路由（后续拆分）
│   │   └── services/
│   │       ├── llm_client.py   # DeepSeek + GLM fallback
│   │       └── asr_client.py   # Qwen3-ASR + SenseVoice
│   └── tests/
│       └── test_clients.py
├── data/
│   ├── problems.json    # 15 道精选题目
│   ├── seed.py          # 入库脚本
│   └── verify_retrieval.py  # 检索验证
├── sql/init.sql         # 数据库 Schema
├── prompts/             # Prompt 模板（5/11 开始）
├── docker-compose.yml
└── .env.example
```

## AI 评价维度

| 维度 | 权重 | 内容 |
|------|------|------|
| 正确性 | 30% | 算法思路是否正确 |
| 复杂度分析 | 20% | 时间/空间复杂度 |
| 表述清晰度 | 20% | 逻辑通顺，讲解清楚 |
| 边界情况 | 15% | 空输入、极值、特殊用例 |
| 反应速度 | 15% | 回答连贯性 |

## 检查点 #1 验证（2026-05-10）

| 模块 | 指标 | 结果 |
|------|------|------|
| 数据库 | PostgreSQL + pgvector 15 道题 | ✅ |
| 检索 | Precision@1: 100%, Precision@3: 100% | ✅ |
| LLM | DeepSeek 对话 + 流式 + GLM fallback | ✅ |
| ASR | Qwen3-ASR-Flash 已配置 | ✅ |
| 客户端 | Flutter 项目骨架 | ✅ |

> **Go/No-Go 决策：通过 → 进入第二阶段（AI 核心逻辑 + Prompt 工程）**
