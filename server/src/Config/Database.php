<?php
/**
 * ZEV Server — Database Connection
 * Hỗ trợ MySQL (cPanel) và SQLite (tự động khởi tạo và dự phòng)
 */

namespace Zev\Config;

class Database
{
    private static ?Database $instance = null;
    private \PDO $pdo;

    private function __construct()
    {
        $configFile = dirname(__DIR__, 2) . '/config/config.php';
        $sampleFile = dirname(__DIR__, 2) . '/config/config.sample.php';
        
        $config = file_exists($configFile) ? (require $configFile) : (require $sampleFile);
        $db = $config['db'] ?? [];
        $driver = $db['driver'] ?? 'mysql';

        if ($driver === 'sqlite') {
            $sqlitePath = $db['path'] ?? (dirname(__DIR__, 2) . '/database/zev.sqlite');
            $this->initSqlite($sqlitePath);
            return;
        }

        // Thử kết nối MySQL
        try {
            $dsn = sprintf(
                'mysql:host=%s;port=%d;dbname=%s;charset=%s',
                $db['host'] ?? 'localhost',
                $db['port'] ?? 3306,
                $db['name'] ?? 'zev_db',
                $db['charset'] ?? 'utf8mb4'
            );

            $options = [
                \PDO::ATTR_ERRMODE            => \PDO::ERRMODE_EXCEPTION,
                \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC,
                \PDO::ATTR_EMULATE_PREPARES   => false,
                \PDO::MYSQL_ATTR_INIT_COMMAND => "SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci",
            ];

            $this->pdo = new \PDO($dsn, $db['user'] ?? 'root', $db['password'] ?? '', $options);

            // Tự động khởi tạo bảng MySQL nếu database mới chưa có dữ liệu
            try {
                $check = $this->pdo->query("SHOW TABLES LIKE 'admins'")->fetch();
                if (!$check) {
                    $schemaPath = dirname(__DIR__, 2) . '/database/schema.sql';
                    if (file_exists($schemaPath)) {
                        $this->pdo->exec(file_get_contents($schemaPath));
                    }
                }
                // Đảm bảo bảng rate_limits luôn tồn tại
                $this->pdo->exec("
                    CREATE TABLE IF NOT EXISTS `rate_limits` (
                        `id` int(11) NOT NULL AUTO_INCREMENT,
                        `identifier` varchar(128) NOT NULL,
                        `endpoint` varchar(128) NOT NULL,
                        `request_count` int(11) NOT NULL DEFAULT 1,
                        `window_start` datetime NOT NULL,
                        `blocked_until` datetime DEFAULT NULL,
                        PRIMARY KEY (`id`),
                        KEY `idx_rate_lookup` (`identifier`, `endpoint`)
                    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
                ");
            } catch (\Throwable $e) {}
        } catch (\PDOException $e) {
            // Nếu không kết nối được MySQL (ví dụ dev local chưa cấu hình MySQL cPanel), fallback sang SQLite
            $sqlitePath = dirname(__DIR__, 2) . '/database/zev.sqlite';
            $this->initSqlite($sqlitePath);
        }
    }

    private function initSqlite(string $path): void
    {
        $dir = dirname($path);
        if (!is_dir($dir)) {
            @mkdir($dir, 0755, true);
        }
        $isNew = !file_exists($path);
        $this->pdo = new \PDO("sqlite:" . $path, null, null, [
            \PDO::ATTR_ERRMODE            => \PDO::ERRMODE_EXCEPTION,
            \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC,
            \PDO::ATTR_EMULATE_PREPARES   => false,
        ]);

        if ($isNew) {
            $this->bootstrapSqlite();
        }
    }

    private function bootstrapSqlite(): void
    {
        // Khởi tạo các bảng SQLite tương đương schema.sql
        $this->pdo->exec("
            CREATE TABLE IF NOT EXISTS admins (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                username TEXT NOT NULL UNIQUE,
                password_hash TEXT NOT NULL,
                display_name TEXT DEFAULT NULL,
                role TEXT NOT NULL DEFAULT 'superadmin',
                is_active INTEGER NOT NULL DEFAULT 1,
                must_change_password INTEGER NOT NULL DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_login_at DATETIME DEFAULT NULL
            );

            CREATE TABLE IF NOT EXISTS activation_keys (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                key_code TEXT NOT NULL UNIQUE,
                duration_days INTEGER NOT NULL DEFAULT 30,
                expires_at DATETIME DEFAULT NULL,
                status TEXT NOT NULL DEFAULT 'active',
                note TEXT DEFAULT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                created_by INTEGER DEFAULT NULL,
                last_activated_at DATETIME DEFAULT NULL,
                revoked_at DATETIME DEFAULT NULL,
                revoked_by INTEGER DEFAULT NULL,
                revoke_reason TEXT DEFAULT NULL
            );

            CREATE TABLE IF NOT EXISTS device_bindings (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                key_id INTEGER NOT NULL,
                device_identifier TEXT NOT NULL,
                device_identifier_hash TEXT NOT NULL,
                ios_version TEXT DEFAULT NULL,
                device_model TEXT DEFAULT NULL,
                device_model_name TEXT DEFAULT NULL,
                app_version TEXT DEFAULT NULL,
                activated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                last_seen_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                is_active INTEGER NOT NULL DEFAULT 1,
                unbound_at DATETIME DEFAULT NULL,
                unbound_by INTEGER DEFAULT NULL
            );

            CREATE TABLE IF NOT EXISTS app_config (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                config_key TEXT NOT NULL UNIQUE,
                config_value TEXT NOT NULL,
                description TEXT DEFAULT NULL,
                is_public INTEGER NOT NULL DEFAULT 1,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_by INTEGER DEFAULT NULL
            );

            CREATE TABLE IF NOT EXISTS games (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                bundle_id TEXT NOT NULL UNIQUE,
                display_name TEXT NOT NULL,
                short_name TEXT NOT NULL,
                logo_url TEXT DEFAULT NULL,
                description TEXT DEFAULT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS feature_categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                game_id INTEGER NOT NULL,
                slug TEXT NOT NULL,
                display_name TEXT NOT NULL,
                logo_url TEXT DEFAULT NULL,
                description TEXT DEFAULT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE (game_id, slug)
            );

            CREATE TABLE IF NOT EXISTS features (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                category_id INTEGER NOT NULL,
                slug TEXT NOT NULL,
                display_name TEXT NOT NULL,
                description TEXT DEFAULT NULL,
                status TEXT NOT NULL DEFAULT 'unsupported',
                file_id INTEGER DEFAULT NULL,
                preview_url TEXT DEFAULT NULL,
                is_active INTEGER NOT NULL DEFAULT 1,
                sort_order INTEGER NOT NULL DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                UNIQUE (category_id, slug)
            );

            CREATE TABLE IF NOT EXISTS file_records (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                original_name TEXT NOT NULL,
                display_name TEXT NOT NULL,
                stored_filename TEXT NOT NULL,
                file_path TEXT NOT NULL,
                file_size INTEGER NOT NULL DEFAULT 0,
                mime_type TEXT DEFAULT NULL,
                checksum_sha256 TEXT NOT NULL,
                game_id INTEGER DEFAULT NULL,
                feature_type TEXT DEFAULT NULL,
                file_version TEXT DEFAULT NULL,
                target_path TEXT DEFAULT 'Documents/',
                status TEXT NOT NULL DEFAULT 'active',
                access_level TEXT NOT NULL DEFAULT 'authenticated',
                description TEXT DEFAULT NULL,
                uploaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                uploaded_by INTEGER DEFAULT NULL,
                updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS download_tokens (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                token TEXT NOT NULL UNIQUE,
                file_id INTEGER NOT NULL,
                key_id INTEGER NOT NULL,
                device_hash TEXT NOT NULL,
                expires_at DATETIME NOT NULL,
                used_at DATETIME DEFAULT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS activity_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                actor_type TEXT NOT NULL DEFAULT 'admin',
                actor_id INTEGER DEFAULT NULL,
                actor_label TEXT DEFAULT NULL,
                action TEXT NOT NULL,
                target_type TEXT DEFAULT NULL,
                target_id INTEGER DEFAULT NULL,
                target_label TEXT DEFAULT NULL,
                details TEXT DEFAULT NULL,
                ip_address TEXT DEFAULT NULL,
                user_agent TEXT DEFAULT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            );

            CREATE TABLE IF NOT EXISTS rate_limits (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                identifier TEXT NOT NULL,
                endpoint TEXT NOT NULL,
                request_count INTEGER NOT NULL DEFAULT 1,
                window_start DATETIME NOT NULL,
                blocked_until DATETIME DEFAULT NULL
            );
        ");

        // Seed admin user: admin / 1
        $adminHash = '$2y$12$88FCiLigLovDPvUJ7LAusuX4fMOZ1znlFGhL3Vr1RnXDpZMQislf2';
        $this->pdo->exec("
            INSERT OR IGNORE INTO admins (id, username, password_hash, display_name, role, is_active, must_change_password)
            VALUES (1, 'admin', '{$adminHash}', 'Quản trị viên Zev', 'superadmin', 1, 0);

            INSERT OR IGNORE INTO app_config (config_key, config_value, description, is_public) VALUES
            ('app_name', 'Zev', 'Tên ứng dụng', 1),
            ('app_version_minimum', '1.0.0', 'Phiên bản iOS app tối thiểu', 1),
            ('maintenance_mode', '0', '1 = bảo trì, 0 = bình thường', 1),
            ('maintenance_message_vi', '', 'Thông báo bảo trì Tiếng Việt', 1),
            ('maintenance_message_en', '', 'Thông báo bảo trì English', 1),
            ('support_zalo', '0365829172', 'Số Zalo hỗ trợ', 1),
            ('buy_key_url', 'https://zalo.me/0365829172', 'Link mua key', 1),
            ('max_devices_per_key', '1', 'Số thiết bị tối đa', 0),
            ('download_token_ttl_seconds', '300', 'TTL download token', 0);

            INSERT OR IGNORE INTO games (id, bundle_id, display_name, short_name, logo_url, sort_order) VALUES
            (1, 'com.dts.freefireth', 'Free Fire Thường', 'FFTH', 'https://files.catbox.moe/kony5d.png', 1),
            (2, 'com.dts.freefiremax', 'Free Fire MAX', 'FFMAX', 'https://files.catbox.moe/kony5d.png', 2);

            INSERT OR IGNORE INTO feature_categories (id, game_id, slug, display_name, logo_url, description, sort_order) VALUES
            (1, 1, 'menu-project', 'Menu Project', 'https://files.catbox.moe/wetz7r.png', 'Menu hack và script tổng hợp', 1),
            (2, 1, 'aim-cache', 'Aim Cache', 'https://files.catbox.moe/z7c8o6.png', 'Tối ưu ngắm và khóa mục tiêu', 2),
            (3, 1, 'modskin-ffth', 'Modskin FFTH', 'https://files.catbox.moe/dvyw27.png', 'Mod trang phục và hiệu ứng nhân vật', 3),
            (4, 1, 'setup-antiban', 'Setup Antiban', '', 'Cấu hình bảo vệ tài khoản qua sing-box', 4),
            (5, 2, 'menu-project', 'Menu Project', 'https://files.catbox.moe/wetz7r.png', 'Menu hack cho Free Fire MAX', 1),
            (6, 2, 'aim-cache', 'Aim Cache', 'https://files.catbox.moe/z7c8o6.png', 'Aim Cache cho Free Fire MAX', 2),
            (7, 2, 'modskin-ffmax', 'Modskin FFMAX', 'https://files.catbox.moe/dvyw27.png', 'Modskin cho Free Fire MAX', 3),
            (8, 2, 'setup-antiban', 'Setup Antiban', '', 'Cấu hình sing-box cho FFMAX', 4);

            INSERT OR IGNORE INTO features (id, category_id, slug, display_name, description, status, sort_order) VALUES
            (1, 1, 'menu-v1', 'Menu V1', 'Menu cơ bản phiên bản 1', 'unsupported', 1),
            (2, 1, 'menu-cheat-external', 'Menu CheatExternal', 'Menu Cheat External an toàn', 'unsupported', 2),
            (3, 2, 'aim-head', 'Aim Head', 'Khóa tâm đầu tỉ lệ cao', 'unsupported', 1),
            (4, 2, 'aim-body', 'Aim Body', 'Khóa tâm thân ổn định', 'unsupported', 2),
            (5, 3, 'modskin-alock', 'Modskin Alock (Preview)', 'Trang phục Alock đặc biệt', 'unsupported', 1),
            (6, 3, 'modskin-katri', 'Modskin Katri (Preview)', 'Trang phục Katri đặc biệt', 'unsupported', 2),
            (7, 4, 'singbox-profile', 'Cấu hình sing-box Antiban', 'Tải file cấu hình sing-box kết nối server', 'unsupported', 1),
            (8, 5, 'menu-max-v1', 'Menu MAX V1', 'Menu cho Free Fire MAX', 'unsupported', 1),
            (9, 6, 'aim-cache-max', 'Aim Cache MAX', 'Aim Cache cho MAX', 'unsupported', 1),
            (10, 7, 'modskin-max-alock', 'Modskin Alock MAX', 'Skin Alock cho MAX', 'unsupported', 1),
            (11, 8, 'singbox-max', 'Cấu hình sing-box MAX', 'File sing-box cho MAX', 'unsupported', 1);
        ");
    }

    public static function getInstance(): Database
    {
        if (self::$instance === null) {
            self::$instance = new self();
        }
        return self::$instance;
    }

    public function getPdo(): \PDO
    {
        return $this->pdo;
    }

    public function query(string $sql, array $params = []): \PDOStatement
    {
        $stmt = $this->pdo->prepare($sql);
        $stmt->execute($params);
        return $stmt;
    }

    public function fetchOne(string $sql, array $params = []): ?array
    {
        $result = $this->query($sql, $params)->fetch();
        return $result ?: null;
    }

    public function fetchAll(string $sql, array $params = []): array
    {
        return $this->query($sql, $params)->fetchAll();
    }

    public function insert(string $sql, array $params = []): int
    {
        $this->query($sql, $params);
        return (int) $this->pdo->lastInsertId();
    }

    public function execute(string $sql, array $params = []): int
    {
        return $this->query($sql, $params)->rowCount();
    }

    private function __clone() {}
}
