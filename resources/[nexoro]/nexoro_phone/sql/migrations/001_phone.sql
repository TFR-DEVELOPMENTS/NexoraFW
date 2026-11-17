CREATE TABLE IF NOT EXISTS nexoro_phones (
    character_id INT UNSIGNED NOT NULL,
    phone_number CHAR(11)     NOT NULL,
    email        VARCHAR(80)  NOT NULL,
    handle       VARCHAR(40)  NOT NULL,
    wallpaper    VARCHAR(40)  NOT NULL DEFAULT 'nexoro_black',
    ringtone     VARCHAR(40)  NOT NULL DEFAULT 'default',
    PRIMARY KEY (character_id),
    UNIQUE KEY uq_phone_number (phone_number),
    UNIQUE KEY uq_phone_email (email),
    UNIQUE KEY uq_phone_handle (handle),
    CONSTRAINT fk_phones_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_phone_contacts (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id INT UNSIGNED NOT NULL,
    name         VARCHAR(30)  NOT NULL,
    number       CHAR(11)     NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uq_contact (character_id, number),
    CONSTRAINT fk_contacts_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_phone_messages (
    id         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    sender     CHAR(11) NOT NULL,
    recipient  CHAR(11) NOT NULL,
    body       VARCHAR(500) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at    TIMESTAMP NULL,
    PRIMARY KEY (id),
    KEY idx_msg_recipient (recipient, read_at),
    KEY idx_msg_pair (sender, recipient, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_phone_calls (
    id               BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    caller           VARCHAR(11) NOT NULL,
    callee           VARCHAR(11) NOT NULL,
    status           VARCHAR(12) NOT NULL,
    duration_seconds INT UNSIGNED NOT NULL DEFAULT 0,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_calls_caller (caller, id),
    KEY idx_calls_callee (callee, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_phone_emails (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    to_address   VARCHAR(80) NOT NULL,
    from_address VARCHAR(80) NOT NULL,
    subject      VARCHAR(60) NOT NULL,
    body         VARCHAR(1000) NOT NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at      TIMESTAMP NULL,
    deleted      TINYINT(1) NOT NULL DEFAULT 0,
    PRIMARY KEY (id),
    KEY idx_mail_to (to_address, deleted, id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_phone_adverts (
    id           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id INT UNSIGNED NOT NULL,
    number       CHAR(11) NOT NULL,
    title        VARCHAR(40) NOT NULL,
    body         VARCHAR(250) NOT NULL,
    price_pence  BIGINT UNSIGNED NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    KEY idx_ads_expiry (expires_at),
    CONSTRAINT fk_ads_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
-- @@

CREATE TABLE IF NOT EXISTS nexoro_phone_posts (
    id           BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    character_id INT UNSIGNED NOT NULL,
    handle       VARCHAR(40) NOT NULL,
    body         VARCHAR(200) NOT NULL,
    created_at   TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_posts_character FOREIGN KEY (character_id) REFERENCES nexoro_characters (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
