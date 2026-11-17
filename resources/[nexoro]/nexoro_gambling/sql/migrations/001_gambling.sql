CREATE TABLE IF NOT EXISTS nexoro_gambling_daily (
    character_id INT UNSIGNED NOT NULL,
    day          INT UNSIGNED NOT NULL,
    spent_pence  BIGINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (character_id, day),
    CONSTRAINT fk_gambling_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
