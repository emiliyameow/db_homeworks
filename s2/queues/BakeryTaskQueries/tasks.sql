-- Очередь задач для пекарни
CREATE TABLE IF NOT EXISTS bakery_db.tasks (
    id BIGSERIAL PRIMARY KEY,
    task_type VARCHAR(50) NOT NULL,          -- тип задачи: 'baking', 'delivery', 'notification' и т.п.
    payload JSONB NOT NULL,                  -- данные задачи (например, { "order_id": 123 })
    status SMALLINT NOT NULL DEFAULT 0,      -- 0 = Ready, 1 = Running, 2 = Completed, 3 = Failed
    priority INT NOT NULL DEFAULT 0,         -- 0 = обычная, 100 = критическая
    scheduled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    attempts INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 3,
    last_error TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    worker_id TEXT                        -- идентификатор воркера, который выполняет задачу
);

-- Индексы для быстрого поиска задач
CREATE INDEX idx_tasks_status_scheduled ON bakery_db.tasks (status, scheduled_at) WHERE status = 0;
CREATE INDEX idx_tasks_priority_created ON bakery_db.tasks (priority DESC, created_at) WHERE status = 0;
CREATE INDEX idx_tasks_worker_status ON bakery_db.tasks (worker_id, status) WHERE status = 1;

-- Частичный индекс только для готовых задач (экономит место)
CREATE INDEX idx_tasks_ready_partial ON bakery_db.tasks (priority DESC, created_at) WHERE status = 0;


-- SQL-запрос для лага (разница между NOW() и created_at самой старой Ready-задачи):
SELECT 
    EXTRACT(EPOCH FROM (NOW() - MIN(created_at))) AS lag_seconds
FROM bakery_db.tasks
WHERE status = 0 AND scheduled_at <= NOW();

-- для измерения пропускной способности
SELECT COUNT(*) AS completed_last_10_seconds
FROM bakery_db.tasks
WHERE status = 2
  AND updated_at > NOW() - INTERVAL '10 seconds';

-- агрессивная настройка autovacuum для таблицы tasks
ALTER TABLE bakery_db.tasks SET (
    autovacuum_enabled = true,
    autovacuum_vacuum_scale_factor = 0.05,      -- запускать при 5% изменений
    autovacuum_vacuum_threshold = 500,          -- минимум 500 мёртвых строк
    autovacuum_vacuum_cost_delay = 5,           -- менее агрессивная задержка (по умолчанию 20)
    autovacuum_vacuum_cost_limit = 1000,        -- увеличиваем лимит
    autovacuum_analyze_scale_factor = 0.02,
    autovacuum_analyze_threshold = 250
);