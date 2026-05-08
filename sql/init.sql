CREATE EXTENSION IF NOT EXISTS vector;

CREATE TABLE IF NOT EXISTS problems (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(200) NOT NULL,
    difficulty VARCHAR(10) CHECK (difficulty IN ('easy', 'medium', 'hard')),
    tags TEXT[],
    description_cn TEXT,
    solution_approach TEXT,
    solution_code TEXT,
    complexity_time VARCHAR(50),
    complexity_space VARCHAR(50),
    key_points TEXT[],
    common_mistakes TEXT[],
    embedding vector(768)
);

CREATE TABLE IF NOT EXISTS analysis_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    problem_id UUID REFERENCES problems(id),
    user_input TEXT,
    asr_text TEXT,
    ai_feedback JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS problems_embedding_idx ON problems USING ivfflat (embedding vector_cosine_ops) WITH (lists = 10);
