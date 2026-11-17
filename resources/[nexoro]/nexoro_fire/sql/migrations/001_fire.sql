CREATE TABLE IF NOT EXISTS nexoro_fire_incidents (
    id          INT UNSIGNED NOT NULL AUTO_INCREMENT,
    kind        VARCHAR(16)  NOT NULL,
    status      VARCHAR(16)  NOT NULL DEFAULT 'open',
    x           DOUBLE NOT NULL,
    y           DOUBLE NOT NULL,
    z           DOUBLE NOT NULL,
    notes       VARCHAR(300) NOT NULL DEFAULT '',
    extricated  INT UNSIGNED NOT NULL DEFAULT 0,
    opened_by   VARCHAR(100) NOT NULL DEFAULT '',
    closed_by   VARCHAR(100) NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    closed_at   TIMESTAMP NULL,
    PRIMARY KEY (id),
    KEY idx_fire_status (status, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
