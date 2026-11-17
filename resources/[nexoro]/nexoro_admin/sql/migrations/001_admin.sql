CREATE TABLE IF NOT EXISTS nexoro_bans (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    license     VARCHAR(64)  NOT NULL,
    player_name VARCHAR(100) NOT NULL DEFAULT '',
    reason      VARCHAR(200) NOT NULL,
    banned_by   VARCHAR(100) NOT NULL,
    banned_by_license VARCHAR(64) NOT NULL DEFAULT '',
    expires_at  TIMESTAMP NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked_at  TIMESTAMP NULL,
    revoked_by  VARCHAR(100) NULL,
    PRIMARY KEY (id),
    KEY idx_bans_license (license)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_ban_identifiers (
    ban_id     INT UNSIGNED NOT NULL,
    identifier VARCHAR(80)  NOT NULL,
    PRIMARY KEY (ban_id, identifier),
    KEY idx_ban_identifier (identifier),
    CONSTRAINT fk_banid_ban FOREIGN KEY (ban_id) REFERENCES nexoro_bans (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_warnings (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    license      VARCHAR(64) NOT NULL,
    character_id INT UNSIGNED NOT NULL DEFAULT 0,
    reason       VARCHAR(200) NOT NULL,
    issued_by    VARCHAR(100) NOT NULL,
    issued_by_license VARCHAR(64) NOT NULL DEFAULT '',
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_warnings_license (license)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_admin_logs (
    id             BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    staff_license  VARCHAR(64)  NOT NULL,
    staff_name     VARCHAR(100) NOT NULL,
    staff_rank     VARCHAR(32)  NOT NULL DEFAULT '',
    action         VARCHAR(40)  NOT NULL,
    target_license VARCHAR(64)  NOT NULL DEFAULT '',
    target_name    VARCHAR(100) NOT NULL DEFAULT '',
    previous_value LONGTEXT NULL,
    new_value      LONGTEXT NULL,
    reason         VARCHAR(200) NOT NULL DEFAULT '',
    created_at     TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_adminlog_staff (staff_license, id),
    KEY idx_adminlog_target (target_license, id),
    KEY idx_adminlog_action (action, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
