CREATE TABLE IF NOT EXISTS nexoro_prison_sentences (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id INT UNSIGNED NOT NULL,
    minutes      INT UNSIGNED NOT NULL,
    offence      VARCHAR(120) NOT NULL DEFAULT '',
    started_at   BIGINT UNSIGNED NOT NULL,
    ends_at      BIGINT UNSIGNED NOT NULL,
    released_at  BIGINT UNSIGNED NULL,
    status       VARCHAR(12) NOT NULL DEFAULT 'serving',
    PRIMARY KEY (id),
    KEY idx_prison_status (status, ends_at),
    KEY idx_prison_character (character_id, status),
    CONSTRAINT fk_prison_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
