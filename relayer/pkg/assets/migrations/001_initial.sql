-- +migrate Up

CREATE TYPE tx_status_enum AS ENUM ('succeed', 'errored', 'processing', 'pending', 'failed');

CREATE TABLE IF NOT EXISTS transactions
(
    id          uuid PRIMARY KEY        DEFAULT gen_random_uuid(),
    chain_id    BIGINT         NOT NULL,
    address     VARCHAR        NOT NULL,
    data        BYTEA,
    gas_limit   BIGINT         NOT NULL,
    raw_tx      BYTEA,
    raw_receipt BYTEA,
    status      tx_status_enum NOT NULL,
    msg         TEXT,
    updated_at  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS transactions_status_idx on transactions (status);

CREATE TABLE IF NOT EXISTS blocks
(
    id       uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    chain_id BIGINT  NOT NULL,
    contract VARCHAR NOT NULL,
    number   BIGINT  NOT NULL,

    UNIQUE (chain_id, contract)
);


-- +migrate Down

DROP TABLE IF EXISTS blocks;
DROP INDEX IF EXISTS transactions_status_idx;
DROP TABLE IF EXISTS transactions;
DROP TYPE tx_status_enum;