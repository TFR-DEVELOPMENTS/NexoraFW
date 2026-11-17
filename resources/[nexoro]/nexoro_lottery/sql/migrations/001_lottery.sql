CREATE TABLE IF NOT EXISTS nexoro_lottery_draws (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    draw_at      BIGINT UNSIGNED NOT NULL,
    carried_pence BIGINT UNSIGNED NOT NULL DEFAULT 0,
    pot_pence    BIGINT UNSIGNED NOT NULL DEFAULT 0,
    numbers      VARCHAR(40) NULL,
    status       VARCHAR(12) NOT NULL DEFAULT 'open',
    PRIMARY KEY (id),
    KEY idx_lottery_status (status, draw_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_lottery_tickets (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    draw_id      INT UNSIGNED NOT NULL,
    character_id INT UNSIGNED NOT NULL,
    numbers      VARCHAR(40) NOT NULL,
    created_at   BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    KEY idx_ticket_draw (draw_id),
    CONSTRAINT fk_ticket_draw FOREIGN KEY (draw_id) REFERENCES nexoro_lottery_draws (id) ON DELETE CASCADE,
    CONSTRAINT fk_ticket_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
