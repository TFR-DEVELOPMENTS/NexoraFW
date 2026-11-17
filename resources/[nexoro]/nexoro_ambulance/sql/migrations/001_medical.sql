CREATE TABLE IF NOT EXISTS nexoro_medical_records (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id INT UNSIGNED NOT NULL,
    kind         VARCHAR(16)  NOT NULL,
    detail       VARCHAR(300) NOT NULL DEFAULT '',
    staff        VARCHAR(100) NOT NULL DEFAULT '',
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_medical_character (character_id, id),
    CONSTRAINT fk_medical_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
