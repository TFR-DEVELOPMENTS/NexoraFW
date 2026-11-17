-- Nexoro Phase 1 schema. Statements are separated by "-- @@" lines.
-- Money is stored as integer pence (BIGINT UNSIGNED): no floats, no negatives.

CREATE TABLE IF NOT EXISTS nexoro_players (
    id                   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    license              VARCHAR(64)  NOT NULL,
    name                 VARCHAR(100) NOT NULL,
    extra_slots          TINYINT UNSIGNED NOT NULL DEFAULT 0,
    active_character_id  INT UNSIGNED NULL,
    playtime_seconds     INT UNSIGNED NOT NULL DEFAULT 0,
    first_seen           TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_seen            TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_players_license (license)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_player_identifiers (
    player_id INT UNSIGNED NOT NULL,
    id_type   VARCHAR(16)  NOT NULL,
    id_value  VARCHAR(80)  NOT NULL,
    PRIMARY KEY (player_id, id_type),
    KEY idx_identifier_lookup (id_type, id_value),
    CONSTRAINT fk_identifiers_player FOREIGN KEY (player_id) REFERENCES nexoro_players (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_jobs (
    name           VARCHAR(50) NOT NULL,
    label          VARCHAR(80) NOT NULL,
    category       VARCHAR(24) NOT NULL DEFAULT 'civilian',
    is_whitelisted TINYINT(1)  NOT NULL DEFAULT 0,
    enabled        TINYINT(1)  NOT NULL DEFAULT 1,
    PRIMARY KEY (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_job_grades (
    job_name     VARCHAR(50)  NOT NULL,
    grade        TINYINT UNSIGNED NOT NULL,
    label        VARCHAR(60)  NOT NULL,
    salary_pence INT UNSIGNED NOT NULL DEFAULT 0,
    permissions  LONGTEXT NULL,
    PRIMARY KEY (job_name, grade),
    CONSTRAINT fk_grades_job FOREIGN KEY (job_name) REFERENCES nexoro_jobs (name) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

INSERT IGNORE INTO nexoro_jobs (name, label, category) VALUES ('unemployed', 'Unemployed', 'civilian')
-- @@

INSERT IGNORE INTO nexoro_job_grades (job_name, grade, label, salary_pence) VALUES ('unemployed', 0, 'Jobseeker', 0)
-- @@

CREATE TABLE IF NOT EXISTS nexoro_characters (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    player_id    INT UNSIGNED NOT NULL,
    slot         TINYINT UNSIGNED NOT NULL,
    citizen_id   VARCHAR(10)  NOT NULL,
    first_name   VARCHAR(24)  NOT NULL,
    last_name    VARCHAR(24)  NOT NULL,
    dob          DATE         NOT NULL,
    gender       VARCHAR(16)  NOT NULL,
    nationality  VARCHAR(40)  NOT NULL,
    height_cm    SMALLINT UNSIGNED NOT NULL,
    biography    VARCHAR(600) NOT NULL DEFAULT '',
    cash_pence   BIGINT UNSIGNED NOT NULL DEFAULT 0,
    bank_pence   BIGINT UNSIGNED NOT NULL DEFAULT 0,
    job          VARCHAR(50)  NOT NULL DEFAULT 'unemployed',
    job_grade    TINYINT UNSIGNED NOT NULL DEFAULT 0,
    pos_x        DOUBLE NULL,
    pos_y        DOUBLE NULL,
    pos_z        DOUBLE NULL,
    pos_heading  DOUBLE NULL,
    health       SMALLINT UNSIGNED NOT NULL DEFAULT 200,
    armour       TINYINT UNSIGNED NOT NULL DEFAULT 0,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_played  TIMESTAMP NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_characters_citizen (citizen_id),
    UNIQUE KEY uq_characters_slot (player_id, slot),
    KEY idx_characters_job (job),
    CONSTRAINT fk_characters_player FOREIGN KEY (player_id) REFERENCES nexoro_players (id) ON DELETE CASCADE,
    CONSTRAINT fk_characters_job FOREIGN KEY (job) REFERENCES nexoro_jobs (name) ON UPDATE CASCADE,
    CONSTRAINT chk_characters_height CHECK (height_cm BETWEEN 100 AND 250)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_character_appearance (
    character_id INT UNSIGNED NOT NULL,
    data         LONGTEXT NOT NULL,
    updated_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (character_id),
    CONSTRAINT fk_appearance_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_character_outfits (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id INT UNSIGNED NOT NULL,
    name         VARCHAR(30)  NOT NULL,
    data         LONGTEXT NOT NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_outfit_name (character_id, name),
    CONSTRAINT fk_outfits_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_player_metadata (
    character_id INT UNSIGNED NOT NULL,
    meta_key     VARCHAR(64)  NOT NULL,
    meta_value   LONGTEXT NOT NULL,
    PRIMARY KEY (character_id, meta_key),
    CONSTRAINT fk_metadata_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_staff_assignments (
    player_id   INT UNSIGNED NOT NULL,
    rank_name   VARCHAR(32)  NOT NULL,
    assigned_by VARCHAR(64)  NULL,
    assigned_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (player_id),
    CONSTRAINT fk_staff_player FOREIGN KEY (player_id) REFERENCES nexoro_players (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_logs (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    category     VARCHAR(32) NOT NULL,
    action       VARCHAR(64) NOT NULL,
    license      VARCHAR(64) NULL,
    character_id INT UNSIGNED NULL,
    data         LONGTEXT NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_logs_category (category, created_at),
    KEY idx_logs_license (license, created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
