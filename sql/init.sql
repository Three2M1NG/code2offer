-- ============================================================
-- code2offer 数据库初始化脚本（课程设计增强版）
-- PostgreSQL 16 + pgvector
-- ============================================================

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================
-- 1. 用户表 — 预留登录功能
-- ============================================================
CREATE TABLE IF NOT EXISTS users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username    VARCHAR(50)  NOT NULL UNIQUE,
    email       VARCHAR(200) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    avatar_url  TEXT,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- ============================================================
-- 2. 题目表 — 经典算法题
-- ============================================================
CREATE TABLE IF NOT EXISTS problems (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title             VARCHAR(200) NOT NULL,
    title_cn          VARCHAR(200),
    difficulty        VARCHAR(10)  NOT NULL CHECK (difficulty IN ('easy', 'medium', 'hard')),
    description_cn    TEXT,
    solution_approach TEXT,
    solution_code     TEXT,
    complexity_time   VARCHAR(50),
    complexity_space  VARCHAR(50),
    key_points        TEXT[],
    common_mistakes   TEXT[],
    embedding         vector(768),
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 3. 标签字典表
-- ============================================================
CREATE TABLE IF NOT EXISTS tags (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL UNIQUE,
    description TEXT
);

-- ============================================================
-- 4. 题目-标签关联表（M:N）
-- ============================================================
CREATE TABLE IF NOT EXISTS problem_tags (
    problem_id UUID NOT NULL REFERENCES problems(id) ON DELETE CASCADE,
    tag_id     INT  NOT NULL REFERENCES tags(id)    ON DELETE CASCADE,
    PRIMARY KEY (problem_id, tag_id)
);

-- ============================================================
-- 5. 评价维度配置表
-- ============================================================
CREATE TABLE IF NOT EXISTS evaluation_criteria (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(50)  NOT NULL,
    name_en     VARCHAR(50)  NOT NULL UNIQUE,
    weight      NUMERIC(5,2) NOT NULL CHECK (weight > 0 AND weight <= 100),
    max_score   INT          NOT NULL DEFAULT 10,
    description TEXT,
    sort_order  INT          NOT NULL DEFAULT 0
);

-- ============================================================
-- 6. 判卷历史表（增强版）
-- ============================================================
CREATE TABLE IF NOT EXISTS analysis_history (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID REFERENCES users(id) ON DELETE SET NULL,
    problem_id   UUID REFERENCES problems(id) ON DELETE SET NULL,
    user_input   TEXT,
    asr_text     TEXT,
    audio_url    TEXT,
    ai_feedback  JSONB,
    overall_score NUMERIC(4,2),
    match_similarity NUMERIC(5,4),
    elapsed_ms   INT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ============================================================
-- 7. 评价明细表 — 将 JSONB 拆分为结构化存储
-- ============================================================
CREATE TABLE IF NOT EXISTS evaluation_details (
    id          SERIAL PRIMARY KEY,
    history_id  UUID         NOT NULL REFERENCES analysis_history(id) ON DELETE CASCADE,
    criteria_id INT          NOT NULL REFERENCES evaluation_criteria(id) ON DELETE RESTRICT,
    score       NUMERIC(4,1) NOT NULL CHECK (score >= 0 AND score <= 10),
    comment     TEXT,
    suggestion  TEXT
);

-- ============================================================
-- 索引
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_problems_embedding
    ON problems USING ivfflat (embedding vector_cosine_ops) WITH (lists = 10);

CREATE INDEX IF NOT EXISTS idx_problems_difficulty
    ON problems(difficulty);

CREATE INDEX IF NOT EXISTS idx_analysis_history_user
    ON analysis_history(user_id);

CREATE INDEX IF NOT EXISTS idx_analysis_history_problem
    ON analysis_history(problem_id);

CREATE INDEX IF NOT EXISTS idx_analysis_history_created
    ON analysis_history(created_at DESC);

CREATE INDEX IF NOT EXISTS idx_evaluation_details_history
    ON evaluation_details(history_id);

-- ============================================================
-- 视图
-- ============================================================

-- 视图1：题目难度统计
CREATE OR REPLACE VIEW v_problem_stats AS
SELECT
    difficulty,
    COUNT(*)                         AS problem_count,
    ROUND(AVG(ah.overall_score), 2)  AS avg_score,
    COUNT(DISTINCT ah.id)            AS attempt_count
FROM problems p
LEFT JOIN analysis_history ah ON ah.problem_id = p.id
GROUP BY difficulty
ORDER BY
    CASE difficulty
        WHEN 'easy'   THEN 1
        WHEN 'medium' THEN 2
        WHEN 'hard'   THEN 3
    END;

-- 视图2：用户判卷表现汇总
CREATE OR REPLACE VIEW v_user_performance AS
SELECT
    u.id          AS user_id,
    u.username,
    COUNT(ah.id)  AS total_attempts,
    ROUND(AVG(ah.overall_score), 2) AS avg_score,
    MAX(ah.overall_score)           AS best_score,
    MIN(ah.overall_score)           AS worst_score
FROM users u
LEFT JOIN analysis_history ah ON ah.user_id = u.id
GROUP BY u.id, u.username;

-- 视图3：最近判卷详情（多表 JOIN）
CREATE OR REPLACE VIEW v_recent_analysis AS
SELECT
    ah.id              AS history_id,
    ah.created_at      AS analysis_time,
    u.username         AS user_name,
    p.title            AS problem_title,
    p.difficulty,
    ah.overall_score,
    ah.match_similarity,
    ah.elapsed_ms,
    string_agg(DISTINCT t.name, ', ') AS tags
FROM analysis_history ah
LEFT JOIN users u       ON u.id   = ah.user_id
LEFT JOIN problems p    ON p.id   = ah.problem_id
LEFT JOIN problem_tags pt ON pt.problem_id = p.id
LEFT JOIN tags t        ON t.id   = pt.tag_id
GROUP BY ah.id, ah.created_at, u.username, p.title, p.difficulty,
         ah.overall_score, ah.match_similarity, ah.elapsed_ms
ORDER BY ah.created_at DESC;

-- ============================================================
-- 触发器
-- ============================================================

-- 触发器1：自动更新 problems.updated_at
CREATE OR REPLACE FUNCTION fn_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_problems_updated_at ON problems;
CREATE TRIGGER trg_problems_updated_at
    BEFORE UPDATE ON problems
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_timestamp();

DROP TRIGGER IF EXISTS trg_users_updated_at ON users;
CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION fn_update_timestamp();

-- 触发器2：验证评价维度权重总和为 100
CREATE OR REPLACE FUNCTION fn_validate_criteria_weight()
RETURNS TRIGGER AS $$
DECLARE
    total_weight NUMERIC;
BEGIN
    SELECT COALESCE(SUM(weight), 0) INTO total_weight FROM evaluation_criteria;
    IF total_weight > 100 THEN
        RAISE EXCEPTION 'Weight sum exceeds 100%%: current=%, max=100', total_weight;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validate_weight ON evaluation_criteria;
CREATE TRIGGER trg_validate_weight
    BEFORE INSERT OR UPDATE ON evaluation_criteria
    FOR EACH ROW
    EXECUTE FUNCTION fn_validate_criteria_weight();

-- ============================================================
-- 种子数据：评价维度（5 维度 × 不同权重）
-- ============================================================
INSERT INTO evaluation_criteria (name, name_en, weight, max_score, description, sort_order) VALUES
    ('正确性',   'correctness',  30, 10, '算法思路是否正确，能否解决给定问题', 1),
    ('复杂度分析', 'complexity', 20, 10, '时间复杂度和空间复杂度分析是否准确', 2),
    ('表述清晰度', 'clarity',    20, 10, '逻辑是否通顺，能否清晰地讲清楚思路', 3),
    ('边界情况',  'edge_cases',  15, 10, '是否考虑了空输入、极值、特殊用例等边界', 4),
    ('反应速度',  'delivery',    15, 10, '回答是否连贯流畅（模拟面试压力下表现）', 5)
ON CONFLICT (name_en) DO NOTHING;

-- 标签种子（覆盖 problems.json 中所有标签）
INSERT INTO tags (name, description) VALUES
    ('Array',            '数组相关算法题'),
    ('Hash Table',       '哈希表/字典'),
    ('Linked List',      '链表操作'),
    ('Tree',             '树结构（二叉树、BST等）'),
    ('DP',               '动态规划'),
    ('String',           '字符串处理'),
    ('Graph',            '图论与遍历'),
    ('Stack',            '栈相关'),
    ('Heap',             '堆/优先队列'),
    ('Greedy',           '贪心算法'),
    ('Binary Search',    '二分查找'),
    ('Two Pointers',     '双指针技巧'),
    ('BFS',              '广度优先搜索'),
    ('DFS',              '深度优先搜索'),
    ('Backtracking',     '回溯算法'),
    ('Iteration',        '迭代遍历'),
    ('Recursion',        '递归算法'),
    ('Sorting',          '排序算法'),
    ('Queue',            '队列结构'),
    ('Design',           '数据结构设计'),
    ('Union Find',       '并查集'),
    ('Matrix',           '矩阵遍历'),
    ('Knapsack',         '背包问题'),
    ('Math',             '数学公式推导'),
    ('Trie',             '字典树/前缀树'),
    ('Divide and Conquer','分治算法')
ON CONFLICT (name) DO NOTHING;
