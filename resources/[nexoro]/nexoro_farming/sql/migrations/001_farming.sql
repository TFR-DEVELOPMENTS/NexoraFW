CREATE TABLE IF NOT EXISTS nexoro_farm_plots (
    plot_id      VARCHAR(40) NOT NULL,
    character_id INT UNSIGNED NOT NULL,
    crop         VARCHAR(30) NOT NULL,
    planted_at   BIGINT UNSIGNED NOT NULL,
    PRIMARY KEY (plot_id),
    KEY idx_plot_character (character_id),
    CONSTRAINT fk_plot_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
