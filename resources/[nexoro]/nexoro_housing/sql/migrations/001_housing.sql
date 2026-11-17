CREATE TABLE IF NOT EXISTS nexoro_properties (
    id           VARCHAR(40)  NOT NULL,
    label        VARCHAR(80)  NOT NULL,
    price_pence  BIGINT UNSIGNED NOT NULL,
    weekly_pence INT UNSIGNED NOT NULL,
    owner_id     INT UNSIGNED NULL,
    arrears      INT UNSIGNED NOT NULL DEFAULT 0,
    next_bill_at BIGINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    KEY idx_property_owner (owner_id),
    CONSTRAINT fk_property_owner FOREIGN KEY (owner_id) REFERENCES nexoro_characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_property_keys (
    property_id  VARCHAR(40) NOT NULL,
    character_id INT UNSIGNED NOT NULL,
    granted_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (property_id, character_id),
    CONSTRAINT fk_pkeys_property FOREIGN KEY (property_id) REFERENCES nexoro_properties (id) ON DELETE CASCADE,
    CONSTRAINT fk_pkeys_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
