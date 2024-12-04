-- +migrate Up

CREATE TABLE IF NOT EXISTS prices
(
    id          uuid PRIMARY KEY         DEFAULT gen_random_uuid(),
    chain_id    BIGINT NOT NULL,
    asset       TEXT   NOT NULL,
    vault       TEXT   NOT NULL,
    asset_price BIGINT NOT NULL,
    share_price BIGINT NOT NULL,
    updated_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    created_at  TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,

    UNIQUE (chain_id, vault)
);

CREATE INDEX IF NOT EXISTS prices_vault_idx on prices (vault);
CREATE INDEX IF NOT EXISTS prices_asset_idx on prices (asset);

-- +migrate Down

DROP INDEX IF EXISTS prices_asset_idx;
DROP INDEX IF EXISTS prices_vault_idx;
DROP TABLE IF EXISTS prices;
