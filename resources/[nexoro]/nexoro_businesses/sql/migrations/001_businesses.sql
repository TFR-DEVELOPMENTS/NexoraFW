CREATE TABLE IF NOT EXISTS nexoro_businesses (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name        VARCHAR(40)  NOT NULL,
    owner_id    INT UNSIGNED NOT NULL,
    bank_pence  BIGINT UNSIGNED NOT NULL DEFAULT 0,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_business_owner (owner_id),
    CONSTRAINT fk_business_owner FOREIGN KEY (owner_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_business_staff (
    business_id  INT UNSIGNED NOT NULL,
    character_id INT UNSIGNED NOT NULL,
    wage_pence   INT UNSIGNED NOT NULL,
    last_paid_at BIGINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (business_id, character_id),
    CONSTRAINT fk_staff_business FOREIGN KEY (business_id) REFERENCES nexoro_businesses (id) ON DELETE CASCADE,
    CONSTRAINT fk_staff_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
