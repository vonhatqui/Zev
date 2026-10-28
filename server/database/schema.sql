-- ============================================================
-- ZEV SERVER — DATABASE SCHEMA
-- Version: 1.0.0
-- Encoding: UTF-8
-- ============================================================

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+07:00";

-- ------------------------------------------------------------
-- Table: admins
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admins` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(64) NOT NULL,
  `password_hash` VARCHAR(255) NOT NULL COMMENT 'bcrypt hash',
  `display_name` VARCHAR(128) DEFAULT NULL,
  `role` ENUM('superadmin','admin','viewer') NOT NULL DEFAULT 'admin',
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `must_change_password` TINYINT(1) NOT NULL DEFAULT 1,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `last_login_at` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: activation_keys
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `activation_keys` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `key_code` VARCHAR(64) NOT NULL COMMENT 'Key nhập bởi user, e.g. ZEV-XXXX-XXXX-XXXX',
  `duration_days` INT UNSIGNED NOT NULL DEFAULT 30,
  `expires_at` DATETIME DEFAULT NULL COMMENT 'NULL = vĩnh viễn',
  `status` ENUM('active','expired','revoked','suspended') NOT NULL DEFAULT 'active',
  `note` TEXT DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `created_by` INT UNSIGNED DEFAULT NULL COMMENT 'FK admins.id',
  `last_activated_at` DATETIME DEFAULT NULL,
  `revoked_at` DATETIME DEFAULT NULL,
  `revoked_by` INT UNSIGNED DEFAULT NULL,
  `revoke_reason` VARCHAR(255) DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_key_code` (`key_code`),
  KEY `idx_status` (`status`),
  KEY `idx_expires_at` (`expires_at`),
  CONSTRAINT `fk_key_created_by` FOREIGN KEY (`created_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_key_revoked_by` FOREIGN KEY (`revoked_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: device_bindings
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `device_bindings` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `key_id` INT UNSIGNED NOT NULL,
  `device_identifier` VARCHAR(128) NOT NULL COMMENT 'IDFV hash, không lưu raw',
  `device_identifier_hash` VARCHAR(64) NOT NULL COMMENT 'SHA-256 của identifier',
  `ios_version` VARCHAR(20) DEFAULT NULL,
  `device_model` VARCHAR(64) DEFAULT NULL COMMENT 'model identifier, e.g. iPhone16,2',
  `device_model_name` VARCHAR(128) DEFAULT NULL COMMENT 'Tên thương mại nếu biết',
  `app_version` VARCHAR(20) DEFAULT NULL,
  `activated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `last_seen_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `unbound_at` DATETIME DEFAULT NULL,
  `unbound_by` INT UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_key_id` (`key_id`),
  KEY `idx_device_hash` (`device_identifier_hash`),
  KEY `idx_is_active` (`is_active`),
  CONSTRAINT `fk_binding_key` FOREIGN KEY (`key_id`) REFERENCES `activation_keys` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_binding_unbound_by` FOREIGN KEY (`unbound_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: app_config
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `app_config` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `config_key` VARCHAR(128) NOT NULL,
  `config_value` TEXT NOT NULL,
  `description` VARCHAR(255) DEFAULT NULL,
  `is_public` TINYINT(1) NOT NULL DEFAULT 1 COMMENT '1 = client có thể đọc',
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` INT UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_config_key` (`config_key`),
  CONSTRAINT `fk_config_updated_by` FOREIGN KEY (`updated_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: games
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `games` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `bundle_id` VARCHAR(128) NOT NULL COMMENT 'e.g. com.dts.freefireth',
  `display_name` VARCHAR(128) NOT NULL,
  `short_name` VARCHAR(64) NOT NULL,
  `logo_url` VARCHAR(512) DEFAULT NULL,
  `description` TEXT DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_bundle_id` (`bundle_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: feature_categories
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `feature_categories` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `game_id` INT UNSIGNED NOT NULL,
  `slug` VARCHAR(64) NOT NULL COMMENT 'e.g. menu-project',
  `display_name` VARCHAR(128) NOT NULL,
  `logo_url` VARCHAR(512) DEFAULT NULL,
  `description` TEXT DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_game_slug` (`game_id`, `slug`),
  KEY `idx_game_id` (`game_id`),
  CONSTRAINT `fk_category_game` FOREIGN KEY (`game_id`) REFERENCES `games` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: features
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `features` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `category_id` INT UNSIGNED NOT NULL,
  `slug` VARCHAR(64) NOT NULL,
  `display_name` VARCHAR(128) NOT NULL,
  `description` TEXT DEFAULT NULL,
  `status` ENUM('ready','loading','unsupported','no_file','incompatible','error') NOT NULL DEFAULT 'unsupported',
  `file_id` INT UNSIGNED DEFAULT NULL,
  `preview_url` VARCHAR(512) DEFAULT NULL,
  `is_active` TINYINT(1) NOT NULL DEFAULT 1,
  `sort_order` INT NOT NULL DEFAULT 0,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_category_slug` (`category_id`, `slug`),
  KEY `idx_category_id` (`category_id`),
  KEY `idx_file_id` (`file_id`),
  CONSTRAINT `fk_feature_category` FOREIGN KEY (`category_id`) REFERENCES `feature_categories` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: ios_compatibility
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `ios_compatibility` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `ios_version` VARCHAR(20) NOT NULL COMMENT 'e.g. 17.0, 17.5, 18.0',
  `game_id` INT UNSIGNED DEFAULT NULL COMMENT 'NULL = áp dụng cho tất cả game',
  `status` ENUM('supported','unsupported','partial') NOT NULL DEFAULT 'unsupported',
  `note` VARCHAR(255) DEFAULT NULL,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `updated_by` INT UNSIGNED DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_ios_game` (`ios_version`, `game_id`),
  KEY `idx_game_id` (`game_id`),
  CONSTRAINT `fk_compat_game` FOREIGN KEY (`game_id`) REFERENCES `games` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_compat_updated_by` FOREIGN KEY (`updated_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: file_records
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `file_records` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `original_name` VARCHAR(255) NOT NULL,
  `display_name` VARCHAR(255) NOT NULL,
  `stored_filename` VARCHAR(255) NOT NULL COMMENT 'Tên file thực tế trên server',
  `file_path` VARCHAR(512) NOT NULL COMMENT 'Đường dẫn tương đối từ uploads/',
  `file_size` BIGINT UNSIGNED NOT NULL DEFAULT 0,
  `mime_type` VARCHAR(128) DEFAULT NULL,
  `checksum_sha256` VARCHAR(64) NOT NULL,
  `game_id` INT UNSIGNED DEFAULT NULL,
  `feature_type` VARCHAR(64) DEFAULT NULL COMMENT 'e.g. menu, aim, modskin, antiban',
  `file_version` VARCHAR(32) DEFAULT NULL,
  `target_path` VARCHAR(255) DEFAULT 'Documents/' COMMENT 'Đích đến trong container app (Documents/, Library/Preferences/, cache/)',
  `status` ENUM('active','disabled','deleted') NOT NULL DEFAULT 'active',
  `access_level` ENUM('public','authenticated','admin') NOT NULL DEFAULT 'authenticated',
  `description` TEXT DEFAULT NULL,
  `uploaded_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `uploaded_by` INT UNSIGNED DEFAULT NULL,
  `updated_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_game_id` (`game_id`),
  KEY `idx_status` (`status`),
  KEY `idx_uploaded_by` (`uploaded_by`),
  CONSTRAINT `fk_file_game` FOREIGN KEY (`game_id`) REFERENCES `games` (`id`) ON DELETE SET NULL,
  CONSTRAINT `fk_file_uploaded_by` FOREIGN KEY (`uploaded_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Thêm FK cho features.file_id sau khi tạo file_records
ALTER TABLE `features` 
  ADD CONSTRAINT `fk_feature_file` FOREIGN KEY (`file_id`) REFERENCES `file_records` (`id`) ON DELETE SET NULL;

-- ------------------------------------------------------------
-- Table: file_version_history
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `file_version_history` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `file_id` INT UNSIGNED NOT NULL,
  `previous_version` VARCHAR(32) DEFAULT NULL,
  `new_version` VARCHAR(32) NOT NULL,
  `changed_by` INT UNSIGNED DEFAULT NULL,
  `change_note` TEXT DEFAULT NULL,
  `changed_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_file_id` (`file_id`),
  CONSTRAINT `fk_fvh_file` FOREIGN KEY (`file_id`) REFERENCES `file_records` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_fvh_admin` FOREIGN KEY (`changed_by`) REFERENCES `admins` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: download_tokens
-- (URL tải xuống có thời hạn)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `download_tokens` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `token` VARCHAR(128) NOT NULL,
  `file_id` INT UNSIGNED NOT NULL,
  `key_id` INT UNSIGNED NOT NULL,
  `device_hash` VARCHAR(64) NOT NULL,
  `expires_at` DATETIME NOT NULL,
  `used_at` DATETIME DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_token` (`token`),
  KEY `idx_file_id` (`file_id`),
  KEY `idx_expires` (`expires_at`),
  CONSTRAINT `fk_dltoken_file` FOREIGN KEY (`file_id`) REFERENCES `file_records` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_dltoken_key` FOREIGN KEY (`key_id`) REFERENCES `activation_keys` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: activity_logs
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `activity_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `actor_type` ENUM('admin','system','api') NOT NULL DEFAULT 'admin',
  `actor_id` INT UNSIGNED DEFAULT NULL,
  `actor_label` VARCHAR(128) DEFAULT NULL COMMENT 'Username or identifier',
  `action` VARCHAR(128) NOT NULL COMMENT 'e.g. key.create, key.revoke, file.upload',
  `target_type` VARCHAR(64) DEFAULT NULL COMMENT 'e.g. key, file, feature',
  `target_id` INT UNSIGNED DEFAULT NULL,
  `target_label` VARCHAR(255) DEFAULT NULL,
  `details` JSON DEFAULT NULL,
  `ip_address` VARCHAR(45) DEFAULT NULL,
  `user_agent` VARCHAR(512) DEFAULT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_actor` (`actor_type`, `actor_id`),
  KEY `idx_action` (`action`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: admin_login_logs
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `admin_login_logs` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `admin_id` INT UNSIGNED DEFAULT NULL,
  `username_attempted` VARCHAR(128) DEFAULT NULL,
  `ip_address` VARCHAR(45) DEFAULT NULL,
  `user_agent` VARCHAR(512) DEFAULT NULL,
  `success` TINYINT(1) NOT NULL DEFAULT 0,
  `fail_reason` VARCHAR(128) DEFAULT NULL,
  `attempted_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_admin_id` (`admin_id`),
  KEY `idx_ip` (`ip_address`),
  KEY `idx_attempted_at` (`attempted_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------------------
-- Table: rate_limits
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `rate_limits` (
  `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `identifier` VARCHAR(128) NOT NULL COMMENT 'IP or device_hash',
  `endpoint` VARCHAR(128) NOT NULL,
  `request_count` INT UNSIGNED NOT NULL DEFAULT 1,
  `window_start` DATETIME NOT NULL,
  `blocked_until` DATETIME DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_id_endpoint` (`identifier`, `endpoint`),
  KEY `idx_blocked_until` (`blocked_until`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- SEED DATA
-- ============================================================

-- Tài khoản Admin mặc định: admin / 1
INSERT INTO `admins` (`id`, `username`, `password_hash`, `display_name`, `role`, `is_active`, `must_change_password`) VALUES
(1, 'admin', '$2y$12$88FCiLigLovDPvUJ7LAusuX4fMOZ1znlFGhL3Vr1RnXDpZMQislf2', 'Quản trị viên Zev', 'superadmin', 1, 0);

-- App Config mặc định
INSERT INTO `app_config` (`config_key`, `config_value`, `description`, `is_public`) VALUES
('app_name', 'Zev', 'Tên ứng dụng', 1),
('app_version_minimum', '1.0.0', 'Phiên bản iOS app tối thiểu được chấp nhận', 1),
('maintenance_mode', '0', '1 = bảo trì, 0 = hoạt động bình thường', 1),
('maintenance_message_vi', '', 'Thông báo bảo trì (Tiếng Việt)', 1),
('maintenance_message_en', '', 'Maintenance message (English)', 1),
('support_zalo', '0365829172', 'Số Zalo hỗ trợ', 1),
('buy_key_url', '', 'Link hướng dẫn mua key', 1),
('terms_url', '', 'Link điều khoản sử dụng', 1),
('privacy_url', '', 'Link chính sách quyền riêng tư', 1),
('max_devices_per_key', '1', 'Số thiết bị tối đa cho một key', 0),
('download_token_ttl_seconds', '300', 'Thời hạn URL tải xuống (giây)', 0),
('api_rate_limit_per_minute', '30', 'Số request tối đa mỗi phút', 0);

-- Games mặc định
INSERT INTO `games` (`bundle_id`, `display_name`, `short_name`, `sort_order`) VALUES
('com.dts.freefireth', 'Free Fire Thường', 'FFTH', 1),
('com.dts.freefiremax', 'Free Fire MAX', 'FFMAX', 2);

-- Feature Categories cho FFTH (game_id = 1)
INSERT INTO `feature_categories` (`game_id`, `slug`, `display_name`, `logo_url`, `description`, `sort_order`) VALUES
(1, 'menu-project', 'Menu Project', 'https://files.catbox.moe/wetz7r.png', 'Menu hack tổng hợp', 1),
(1, 'aim-cache', 'Aim Cache', 'https://files.catbox.moe/z7c8o6.png', 'Hỗ trợ ngắm mục tiêu', 2),
(1, 'modskin-ffth', 'Modskin FFTH', 'https://files.catbox.moe/dvyw27.png', 'Thay đổi giao diện nhân vật', 3),
(1, 'setup-antiban', 'Setup Antiban', NULL, 'Cấu hình mạng sing-box', 4);

-- Feature Categories cho FFMAX (game_id = 2)
INSERT INTO `feature_categories` (`game_id`, `slug`, `display_name`, `description`, `sort_order`) VALUES
(2, 'setup-antiban', 'Setup Antiban', 'Cấu hình mạng sing-box', 1);

-- Features mặc định cho FFTH Menu Project (category_id = 1)
INSERT INTO `features` (`category_id`, `slug`, `display_name`, `description`, `status`, `sort_order`) VALUES
(1, 'menu-v1', 'Menu V1', 'Menu cơ bản phiên bản 1', 'unsupported', 1),
(1, 'menu-cheat-external', 'Menu CheatExternal', 'Menu cheat ngoài tiến trình', 'unsupported', 2);

-- Features cho Aim Cache (category_id = 2)
INSERT INTO `features` (`category_id`, `slug`, `display_name`, `description`, `status`, `sort_order`) VALUES
(2, 'aim-head', 'Aim Head', 'Khóa ngắm đầu', 'unsupported', 1),
(2, 'aim-body', 'Aim Body', 'Khóa ngắm thân', 'unsupported', 2),
(2, 'aim-neck', 'Aim Neck', 'Khóa ngắm cổ', 'unsupported', 3);

-- Features cho Modskin FFTH (category_id = 3)
INSERT INTO `features` (`category_id`, `slug`, `display_name`, `description`, `status`, `sort_order`) VALUES
(3, 'modskin-alock', 'Modskin Alock (Preview)', 'Giao diện Alock - xem trước', 'unsupported', 1),
(3, 'modskin-katri', 'Modskin Katri (Preview)', 'Giao diện Katri - xem trước', 'unsupported', 2);

-- Features cho Setup Antiban (category_id = 4)
INSERT INTO `features` (`category_id`, `slug`, `display_name`, `description`, `status`, `sort_order`) VALUES
(4, 'singbox-config', 'Cấu hình sing-box', 'File cấu hình sing-box cho FFTH', 'no_file', 1);
