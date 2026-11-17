CREATE TABLE IF NOT EXISTS nexoro_pitches (
    id           VARCHAR(40) NOT NULL,
    owner_id     INT UNSIGNED NULL,
    claimed_at   BIGINT UNSIGNED NULL,
    PRIMARY KEY (id),
    KEY idx_pitch_owner (owner_id),
    CONSTRAINT fk_pitch_owner FOREIGN KEY (owner_id) REFERENCES nexoro_characters (id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_pitch_notices (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    pitch_id     VARCHAR(40) NOT NULL,
    issued_by    VARCHAR(60) NOT NULL,
    issued_at    BIGINT UNSIGNED NOT NULL,
    deadline     BIGINT UNSIGNED NOT NULL,
    status       VARCHAR(12) NOT NULL DEFAULT 'active',
    PRIMARY KEY (id),
    KEY idx_notice_pitch (pitch_id, status),
    CONSTRAINT fk_notice_pitch FOREIGN KEY (pitch_id) REFERENCES nexoro_pitches (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_pitch_warrants (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    pitch_id     VARCHAR(40) NOT NULL,
    issued_by    VARCHAR(60) NOT NULL,
    reason       VARCHAR(200) NOT NULL,
    issued_at    BIGINT UNSIGNED NOT NULL,
    expires_at   BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    KEY idx_warrant_pitch (pitch_id, expires_at),
    CONSTRAINT fk_warrant_pitch FOREIGN KEY (pitch_id) REFERENCES nexoro_pitches (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
