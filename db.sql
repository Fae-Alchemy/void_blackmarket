CREATE TABLE IF NOT EXISTS `void_blackmarkets` (
    `id` INT AUTO_INCREMENT PRIMARY KEY,
    `name` VARCHAR(50) NOT NULL UNIQUE,
    `label` VARCHAR(100) NOT NULL,
    `coords` TEXT NOT NULL, -- JSON string representing x, y, z, h
    `ped` VARCHAR(50) NOT NULL DEFAULT 'g_m_m_mexboss_01',
    `blip` TEXT DEFAULT NULL, -- JSON string representing sprite, color, scale
    `balance` INT NOT NULL DEFAULT 0,
    `tax_rate` INT NOT NULL DEFAULT 10,
    `items` LONGTEXT NOT NULL DEFAULT '[]', -- JSON array of items [{name, price, stock}]
    `offline_access` TINYINT(1) NOT NULL DEFAULT 1,
    `owner_job` VARCHAR(50) NOT NULL,
    `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
