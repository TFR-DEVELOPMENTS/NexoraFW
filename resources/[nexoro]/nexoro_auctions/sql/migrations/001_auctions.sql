CREATE TABLE IF NOT EXISTS nexoro_auctions (
    id            INT UNSIGNED NOT NULL AUTO_INCREMENT,
    seller_id     INT UNSIGNED NOT NULL,
    item          VARCHAR(50)  NOT NULL,
    amount        INT UNSIGNED NOT NULL,
    start_pence   BIGINT UNSIGNED NOT NULL,
    current_pence BIGINT UNSIGNED NOT NULL,
    bidder_id     INT UNSIGNED NULL,
    ends_at       BIGINT UNSIGNED NOT NULL,
    status        VARCHAR(16) NOT NULL DEFAULT 'active',
    PRIMARY KEY (id),
    KEY idx_auction_status (status, ends_at),
    CONSTRAINT fk_auction_seller FOREIGN KEY (seller_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
