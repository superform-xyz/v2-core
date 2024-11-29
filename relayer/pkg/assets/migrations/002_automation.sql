-- +migrate Up

CREATE TYPE task_status_enum AS ENUM ('created', 'processing', 'finished', 'failed');

CREATE TABLE tasks
(
    id             uuid PRIMARY KEY         DEFAULT gen_random_uuid(),
    name           TEXT                     NOT NULL,
    input          BYTEA                    NOT NULL,
    output         BYTEA,
    execution_time TIMESTAMP WITH TIME ZONE NOT NULL,
    repeat         BIGINT                   NOT NULL,
    status         task_status_enum         NOT NULL,
    error          TEXT,
    created_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at     TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (id, name)
);

CREATE INDEX IF NOT EXISTS tasks_status_idx on tasks (status);

-- +migrate Down

DROP INDEX IF EXISTS tasks_status_idx;
DROP TABLE IF EXISTS tasks;
DROP TYPE task_status_enum;
