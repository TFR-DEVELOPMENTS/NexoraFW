CREATE TABLE IF NOT EXISTS nexoro_inventories (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    owner_type   VARCHAR(16) NOT NULL,
    owner_id     VARCHAR(64) NOT NULL,
    label        VARCHAR(60) NOT NULL DEFAULT '',
    slots        SMALLINT UNSIGNED NOT NULL,
    max_weight_g INT UNSIGNED NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_inventory_owner (owner_type, owner_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_inventory_items (
    inventory_id INT UNSIGNED NOT NULL,
    slot         SMALLINT UNSIGNED NOT NULL,
    item         VARCHAR(50) NOT NULL,
    amount       INT UNSIGNED NOT NULL,
    metadata     LONGTEXT NOT NULL,
    PRIMARY KEY (inventory_id, slot),
    KEY idx_inventory_item (item),
    CONSTRAINT fk_invitems_inventory FOREIGN KEY (inventory_id) REFERENCES nexoro_inventories (id) ON DELETE CASCADE,
    CONSTRAINT chk_invitems_amount CHECK (amount > 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
