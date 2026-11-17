CREATE TABLE IF NOT EXISTS nexoro_police_records (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id INT UNSIGNED NOT NULL,
    kind         VARCHAR(16)  NOT NULL,
    detail       VARCHAR(300) NOT NULL DEFAULT '',
    status       VARCHAR(16)  NOT NULL DEFAULT 'open',
    amount_pence BIGINT UNSIGNED NOT NULL DEFAULT 0,
    officer      VARCHAR(100) NOT NULL DEFAULT '',
    callsign     VARCHAR(12)  NOT NULL DEFAULT '',
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_police_character (character_id, id),
    KEY idx_police_open (kind, status),
    CONSTRAINT fk_police_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_police_evidence (
    id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    reference  VARCHAR(20)  NOT NULL,
    officer    VARCHAR(100) NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_evidence_reference (reference)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
