<?php
/**
 * ZEV Admin — Authentication Handler
 */

namespace Zev\Auth;

use Zev\Config\Database;

class AdminAuth
{
    private static Database $db;

    public static function init(): void
    {
        $config = require ZEV_ROOT . '/config/config.php';
        if (session_status() === PHP_SESSION_NONE) {
            ini_set('session.cookie_httponly', 1);
            ini_set('session.cookie_samesite', 'Strict');
            if (isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on') {
                ini_set('session.cookie_secure', 1);
            }
            session_name($config['admin']['session_key'] ?? 'zev_admin');
            session_start();
        }
        self::$db = Database::getInstance();
    }

    /**
     * Kiểm tra đã đăng nhập chưa — nếu chưa redirect về login
     */
    public static function requireLogin(): void
    {
        self::init();
        if (empty($_SESSION['admin_id'])) {
            header('Location: /admin/login.php');
            exit;
        }

        // Kiểm tra tài khoản vẫn active
        $admin = self::$db->fetchOne(
            "SELECT id, username, display_name, role, must_change_password, is_active 
             FROM admins WHERE id = ? LIMIT 1",
            [(int)$_SESSION['admin_id']]
        );

        if (!$admin || !$admin['is_active']) {
            self::logout();
        }

        // Yêu cầu đổi mật khẩu lần đầu
        if ($admin['must_change_password'] && !str_contains($_SERVER['REQUEST_URI'], 'change-password')) {
            header('Location: /admin/change-password.php');
            exit;
        }

        $_SESSION['admin'] = $admin;
    }

    /**
     * Attempt login — trả về ['success' => bool, 'message' => string]
     */
    public static function login(string $username, string $password, string $ip): array
    {
        self::init();

        $config = require ZEV_ROOT . '/config/config.php';
        $maxAttempts = (int) ($config['admin']['max_login_attempts'] ?? 5);

        // Kiểm tra IP block (đơn giản)
        $recentFails = self::$db->fetchOne(
            "SELECT COUNT(*) as cnt FROM admin_login_logs 
             WHERE ip_address = ? AND success = 0 AND attempted_at > DATE_SUB(NOW(), INTERVAL 30 MINUTE)",
            [$ip]
        );

        if ((int)($recentFails['cnt'] ?? 0) >= $maxAttempts) {
            self::logLogin(null, $username, $ip, false, 'ip_blocked');
            return ['success' => false, 'message' => 'Quá nhiều lần đăng nhập thất bại. Vui lòng thử lại sau 30 phút.'];
        }

        $admin = self::$db->fetchOne(
            "SELECT * FROM admins WHERE username = ? AND is_active = 1 LIMIT 1",
            [$username]
        );

        if (!$admin || !password_verify($password, $admin['password_hash'])) {
            self::logLogin($admin['id'] ?? null, $username, $ip, false, 'invalid_credentials');
            return ['success' => false, 'message' => 'Tên đăng nhập hoặc mật khẩu không đúng.'];
        }

        // Đăng nhập thành công
        session_regenerate_id(true);
        $_SESSION['admin_id']  = $admin['id'];

        self::$db->execute(
            "UPDATE admins SET last_login_at = NOW() WHERE id = ?",
            [$admin['id']]
        );

        self::logLogin($admin['id'], $username, $ip, true, null);

        return ['success' => true, 'message' => 'Đăng nhập thành công.'];
    }

    public static function logout(): void
    {
        self::init();
        session_destroy();
        header('Location: /admin/login.php');
        exit;
    }

    public static function currentAdmin(): ?array
    {
        return $_SESSION['admin'] ?? null;
    }

    public static function requireRole(string ...$roles): void
    {
        $admin = self::currentAdmin();
        if (!$admin || !in_array($admin['role'], $roles)) {
            http_response_code(403);
            echo '<h1>403 — Không có quyền truy cập</h1>';
            exit;
        }
    }

    private static function logLogin(?int $adminId, string $username, string $ip, bool $success, ?string $reason): void
    {
        try {
            self::$db->insert(
                "INSERT INTO admin_login_logs (admin_id, username_attempted, ip_address, user_agent, success, fail_reason) 
                 VALUES (?, ?, ?, ?, ?, ?)",
                [$adminId, $username, $ip, $_SERVER['HTTP_USER_AGENT'] ?? '', (int)$success, $reason]
            );
        } catch (\Throwable $e) {}
    }

    /**
     * Tạo tài khoản admin đầu tiên (chỉ chạy một lần khi setup)
     */
    public static function createFirstAdmin(string $username, string $password): int
    {
        $hash = password_hash($password, PASSWORD_BCRYPT, ['cost' => 12]);
        return self::$db->insert(
            "INSERT INTO admins (username, password_hash, display_name, role, must_change_password) 
             VALUES (?, ?, 'Quản trị viên', 'superadmin', 1)",
            [$username, $hash]
        );
    }
}
