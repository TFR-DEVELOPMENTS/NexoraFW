CREATE TABLE IF NOT EXISTS nexoro_vehicle_thefts (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    plate        CHAR(8) NOT NULL,
    thief_id     INT UNSIGNED NOT NULL,
    stolen_at    BIGINT UNSIGNED NOT NULL,
    recovered_at BIGINT UNSIGNED NULL,
    PRIMARY KEY (id),
    KEY idx_theft_plate (plate, recovered_at),
    CONSTRAINT fk_theft_thief FOREIGN KEY (thief_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
