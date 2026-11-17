-- Immutable ledger. No foreign key on purpose: history survives character deletion for auditing.
CREATE TABLE IF NOT EXISTS nexoro_transactions (
    id                  BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id        INT UNSIGNED NOT NULL,
    citizen_id          VARCHAR(10)  NOT NULL,
    account             VARCHAR(8)   NOT NULL DEFAULT 'bank',
    type                VARCHAR(16)  NOT NULL,
    delta_pence         BIGINT       NOT NULL,
    balance_after_pence BIGINT UNSIGNED NOT NULL,
    counterparty        VARCHAR(60)  NULL,
    note                VARCHAR(100) NOT NULL DEFAULT '',
    created_at          TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_tx_character (character_id, id),
    KEY idx_tx_created (created_at),
    KEY idx_tx_large (delta_pence)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
