CREATE TABLE IF NOT EXISTS nexoro_vehicles (
    id                      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    plate                   CHAR(8)      NOT NULL,
    owner_id                INT UNSIGNED NOT NULL,
    model                   VARCHAR(32)  NOT NULL,
    status                  VARCHAR(12)  NOT NULL DEFAULT 'stored',
    garage                  VARCHAR(40)  NOT NULL DEFAULT '',
    fuel                    DOUBLE NOT NULL DEFAULT 100,
    engine                  DOUBLE NOT NULL DEFAULT 1000,
    body                    DOUBLE NOT NULL DEFAULT 1000,
    mileage_m               BIGINT UNSIGNED NOT NULL DEFAULT 0,
    props                   LONGTEXT NOT NULL,
    insurance_expires       TIMESTAMP NULL DEFAULT NULL,
    mot_expires             TIMESTAMP NULL DEFAULT NULL,
    impound_reason          VARCHAR(100) NOT NULL DEFAULT '',
    impound_fee_pence       BIGINT UNSIGNED NOT NULL DEFAULT 0,
    purchase_price_pence    BIGINT UNSIGNED NOT NULL DEFAULT 0,
    finance_remaining_pence BIGINT UNSIGNED NOT NULL DEFAULT 0,
    finance_payment_pence   BIGINT UNSIGNED NOT NULL DEFAULT 0,
    finance_next_due        TIMESTAMP NULL DEFAULT NULL,
    finance_missed          TINYINT UNSIGNED NOT NULL DEFAULT 0,
    created_at              TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_vehicle_plate (plate),
    KEY idx_vehicle_owner (owner_id, status),
    KEY idx_vehicle_status (status),
    KEY idx_vehicle_finance (finance_remaining_pence, finance_next_due),
    CONSTRAINT fk_vehicle_owner FOREIGN KEY (owner_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_vehicle_keys (
    vehicle_id   INT UNSIGNED NOT NULL,
    character_id INT UNSIGNED NOT NULL,
    granted_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (vehicle_id, character_id),
    CONSTRAINT fk_keys_vehicle FOREIGN KEY (vehicle_id) REFERENCES nexoro_vehicles (id) ON DELETE CASCADE,
    CONSTRAINT fk_keys_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_vehicle_history (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    vehicle_id INT UNSIGNED NOT NULL,
    event      VARCHAR(24)  NOT NULL,
    detail     VARCHAR(200) NOT NULL DEFAULT '',
    actor      VARCHAR(60)  NOT NULL DEFAULT '',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_history_vehicle (vehicle_id, id),
    CONSTRAINT fk_history_vehicle FOREIGN KEY (vehicle_id) REFERENCES nexoro_vehicles (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
