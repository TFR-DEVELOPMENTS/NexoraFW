CREATE TABLE IF NOT EXISTS nexoro_crews (
    id         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    name       VARCHAR(24) NOT NULL,
    leader_id  INT UNSIGNED NOT NULL,
    created_at BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_crew_name (name),
    CONSTRAINT fk_crew_leader FOREIGN KEY (leader_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_crew_members (
    character_id INT UNSIGNED NOT NULL,
    crew_id      INT UNSIGNED NOT NULL,
    joined_at    BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (character_id),
    KEY idx_crew_members (crew_id),
    CONSTRAINT fk_member_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE,
    CONSTRAINT fk_member_crew FOREIGN KEY (crew_id) REFERENCES nexoro_crews (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
