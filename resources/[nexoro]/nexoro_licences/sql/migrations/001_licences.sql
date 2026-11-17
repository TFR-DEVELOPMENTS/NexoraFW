CREATE TABLE IF NOT EXISTS nexoro_licences (
    character_id INT UNSIGNED NOT NULL,
    kind         VARCHAR(16) NOT NULL,
    issued_at    BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (character_id, kind),
    CONSTRAINT fk_licences_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
