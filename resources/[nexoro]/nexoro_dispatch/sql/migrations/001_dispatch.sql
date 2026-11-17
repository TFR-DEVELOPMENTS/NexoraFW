CREATE TABLE IF NOT EXISTS nexoro_dispatch_incidents (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    source      VARCHAR(12)  NOT NULL DEFAULT 'manual',
    kind        VARCHAR(16)  NOT NULL,
    priority    TINYINT UNSIGNED NOT NULL DEFAULT 2,
    status      VARCHAR(12)  NOT NULL DEFAULT 'open',
    description VARCHAR(300) NOT NULL DEFAULT '',
    caller      VARCHAR(11)  NOT NULL DEFAULT '',
    x           DOUBLE NOT NULL,
    y           DOUBLE NOT NULL,
    z           DOUBLE NOT NULL,
    created_by  VARCHAR(100) NOT NULL DEFAULT '',
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at   TIMESTAMP NULL,
    closed_by   VARCHAR(100) NULL,
    PRIMARY KEY (id),
    KEY idx_dispatch_status (status, priority, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_dispatch_assignments (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    incident_id  INT UNSIGNED NOT NULL,
    character_id INT UNSIGNED NOT NULL,
    callsign     VARCHAR(12) NOT NULL DEFAULT '',
    job          VARCHAR(50) NOT NULL DEFAULT '',
    status       VARCHAR(12) NOT NULL DEFAULT 'en_route',
    assigned_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_assignment (incident_id, character_id),
    KEY idx_assignment_character (character_id, status),
    CONSTRAINT fk_assignment_incident FOREIGN KEY (incident_id) REFERENCES nexoro_dispatch_incidents (id) ON DELETE CASCADE,
    CONSTRAINT fk_assignment_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
