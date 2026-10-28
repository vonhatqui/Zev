<?php
/**
 * ZEV Admin — Key Actions (AJAX/POST)
 * Kích hoạt, vô hiệu hóa, gia hạn, xoá key
 */

define('ZEV_ROOT', dirname(__DIR__, 2));
require_once ZEV_ROOT . '/src/helpers.php';
require_once ZEV_ROOT . '/src/Config/Database.php';
require_once ZEV_ROOT . '/src/Auth/AdminAuth.php';

use Zev\Config\Database;
use Zev\Auth\AdminAuth;

AdminAuth::requireAuth();

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    jsonResponse(['status' => 'error', 'message' => 'Phương thức không hợp lệ'], 405);
}

$action = sanitize($_POST['action'] ?? '');
$keyId  = (int)($_POST['id'] ?? 0);

if (!$keyId || empty($action)) {
    jsonResponse(['status' => 'error', 'message' => 'Thiếu tham số'], 400);
}

$db = Database::getInstance();
$key = $db->fetchOne("SELECT * FROM activation_keys WHERE id = ?", [$keyId]);

if (!$key) {
    jsonResponse(['status' => 'error', 'message' => 'Key không tồn tại'], 404);
}

switch ($action) {
    case 'toggle_status':
        $newStatus = ($key['status'] === 'active') ? 'revoked' : 'active';
        $db->execute("UPDATE activation_keys SET status = ?, updated_at = NOW() WHERE id = ?", [$newStatus, $keyId]);
        jsonResponse([
            'status' => 'success',
            'message' => 'Đã đổi trạng thái sang: ' . $newStatus,
            'new_status' => $newStatus
        ]);
        break;

    case 'reset_hwid':
        $db->execute("UPDATE activation_keys SET hwid_lock = NULL, device_name = NULL, last_used_at = NULL, updated_at = NOW() WHERE id = ?", [$keyId]);
        jsonResponse([
            'status' => 'success',
            'message' => 'Đã reset khóa thiết bị (HWID) thành công!'
        ]);
        break;

    case 'extend_days':
        $days = (int)($_POST['days'] ?? 30);
        if ($days <= 0) $days = 30;
        
        $currentExpiry = $key['expires_at'];
        if (!$currentExpiry || strtotime($currentExpiry) < time()) {
            $newExpiry = date('Y-m-d H:i:s', strtotime("+{$days} days"));
        } else {
            $newExpiry = date('Y-m-d H:i:s', strtotime("{$currentExpiry} +{$days} days"));
        }

        $db->execute("UPDATE activation_keys SET expires_at = ?, status = 'active', updated_at = NOW() WHERE id = ?", [$newExpiry, $keyId]);
        jsonResponse([
            'status' => 'success',
            'message' => "Đã gia hạn thêm {$days} ngày. Hạn mới: {$newExpiry}",
            'new_expiry' => $newExpiry
        ]);
        break;

    case 'delete':
        $db->execute("DELETE FROM activation_keys WHERE id = ?", [$keyId]);
        jsonResponse([
            'status' => 'success',
            'message' => 'Đã xoá key thành công!'
        ]);
        break;

    default:
        jsonResponse(['status' => 'error', 'message' => 'Hành động không xác định'], 400);
        break;
}
