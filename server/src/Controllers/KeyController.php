<?php
/**
 * ZEV — Key Controller
 * Xử lý xác minh key, refresh và unbind thiết bị
 */

namespace Zev\Controllers;

use Zev\Config\Database;

class KeyController
{
    private Database $db;
    private array $config;

    public function __construct()
    {
        $this->db     = Database::getInstance();
        $this->config = require ZEV_ROOT . '/config/config.php';
    }

    /**
     * POST /api/v1/auth/verify
     * Body: { key, device_id, ios_version, device_model, app_version }
     */
    public function verify(): never
    {
        $body = getJsonBody();

        $keyCode      = sanitizeString($body['key'] ?? '', 64);
        $deviceId     = sanitizeString($body['device_id'] ?? '', 128);
        $iosVersion   = sanitizeString($body['ios_version'] ?? '', 20);
        $deviceModel  = sanitizeString($body['device_model'] ?? '', 64);
        $appVersion   = sanitizeString($body['app_version'] ?? '', 20);

        // Validate
        if (empty($keyCode)) {
            jsonResponse(400, 'error', 'Vui lòng nhập key kích hoạt.');
        }
        if (empty($deviceId)) {
            jsonResponse(400, 'error', 'Không xác định được thiết bị.');
        }

        $deviceHash = hashDeviceId($deviceId);

        // Lấy thông tin key
        $key = $this->db->fetchOne(
            "SELECT * FROM activation_keys WHERE key_code = ? LIMIT 1",
            [$keyCode]
        );

        if (!$key) {
            $this->logActivity('api', null, 'auth.verify.invalid_key', 'key', null, $keyCode);
            jsonResponse(404, 'error', 'Key không tồn tại hoặc không hợp lệ.');
        }

        // Kiểm tra trạng thái key
        if ($key['status'] === 'revoked') {
            jsonResponse(403, 'error', 'Key đã bị thu hồi. Liên hệ hỗ trợ để biết thêm chi tiết.');
        }
        if ($key['status'] === 'suspended') {
            jsonResponse(403, 'error', 'Key tạm thời bị khóa. Liên hệ hỗ trợ.');
        }
        if ($key['status'] === 'expired') {
            jsonResponse(403, 'error', 'Key đã hết hạn. Vui lòng gia hạn hoặc mua key mới.');
        }

        // Kiểm tra expires_at
        if ($key['expires_at'] !== null) {
            $now       = new \DateTime();
            $expiresAt = new \DateTime($key['expires_at']);
            if ($now > $expiresAt) {
                // Cập nhật trạng thái expired
                $this->db->execute(
                    "UPDATE activation_keys SET status = 'expired' WHERE id = ?",
                    [$key['id']]
                );
                jsonResponse(403, 'error', 'Key đã hết hạn. Vui lòng gia hạn hoặc mua key mới.');
            }
        }

        // Kiểm tra binding hiện tại
        $maxDevices    = (int) $this->getConfig('max_devices_per_key', 1);
        $activeBinding = $this->db->fetchOne(
            "SELECT * FROM device_bindings WHERE key_id = ? AND is_active = 1 LIMIT 1",
            [$key['id']]
        );

        if ($activeBinding) {
            // Đã có thiết bị liên kết
            if ($activeBinding['device_identifier_hash'] !== $deviceHash) {
                // Thiết bị khác đang sử dụng key này
                jsonResponse(403, 'error', 'Key này đã được liên kết với thiết bị khác. Liên hệ hỗ trợ để hủy liên kết.');
            }

            // Cùng thiết bị — cập nhật last_seen
            $this->db->execute(
                "UPDATE device_bindings SET last_seen_at = NOW(), ios_version = ?, device_model = ?, app_version = ? WHERE id = ?",
                [$iosVersion, $deviceModel, $appVersion, $activeBinding['id']]
            );

            $this->db->execute(
                "UPDATE activation_keys SET last_activated_at = NOW() WHERE id = ?",
                [$key['id']]
            );

        } else {
            // Thiết bị mới — tạo binding
            $this->db->insert(
                "INSERT INTO device_bindings (key_id, device_identifier, device_identifier_hash, ios_version, device_model, app_version, activated_at, last_seen_at) 
                 VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())",
                [$key['id'], $this->maskDeviceId($deviceId), $deviceHash, $iosVersion, $deviceModel, $appVersion]
            );

            $this->db->execute(
                "UPDATE activation_keys SET last_activated_at = NOW() WHERE id = ?",
                [$key['id']]
            );
        }

        // Lấy cấu hình iOS compatibility
        $iosCompat = 'unsupported';
        if ($iosVersion) {
            $compat = $this->db->fetchOne(
                "SELECT status FROM ios_compatibility WHERE ios_version = ? AND game_id IS NULL LIMIT 1",
                [$iosVersion]
            );
            $iosCompat = $compat['status'] ?? 'unsupported';
        }

        $this->logActivity('api', null, 'auth.verify.success', 'key', $key['id'], $keyCode);

        jsonResponse(200, 'success', 'Kích hoạt thành công.', [
            'key' => [
                'code'       => $keyCode,
                'status'     => $key['status'],
                'expires_at' => $key['expires_at'],
                'is_lifetime'=> $key['expires_at'] === null,
            ],
            'device' => [
                'model'          => $deviceModel,
                'ios_version'    => $iosVersion,
                'app_version'    => $appVersion,
                'ios_compatible' => $iosCompat,
            ],
        ]);
    }

    /**
     * POST /api/v1/auth/refresh
     * Body: { key, device_id }
     */
    public function refresh(): never
    {
        $body      = getJsonBody();
        $keyCode   = sanitizeString($body['key'] ?? '', 64);
        $deviceId  = sanitizeString($body['device_id'] ?? '', 128);

        if (empty($keyCode) || empty($deviceId)) {
            jsonResponse(400, 'error', 'Thiếu thông tin.');
        }

        $deviceHash = hashDeviceId($deviceId);

        $key = $this->db->fetchOne(
            "SELECT ak.*, db.is_active as binding_active, db.device_identifier_hash
             FROM activation_keys ak
             LEFT JOIN device_bindings db ON db.key_id = ak.id AND db.is_active = 1
             WHERE ak.key_code = ? LIMIT 1",
            [$keyCode]
        );

        if (!$key) {
            jsonResponse(404, 'error', 'Key không tồn tại.');
        }

        // Kiểm tra binding
        if (!$key['binding_active'] || $key['device_identifier_hash'] !== $deviceHash) {
            jsonResponse(403, 'error', 'Thiết bị không khớp với key này.');
        }

        // Kiểm tra hết hạn
        if ($key['expires_at'] !== null && new \DateTime() > new \DateTime($key['expires_at'])) {
            jsonResponse(403, 'error', 'Key đã hết hạn.');
        }

        if ($key['status'] !== 'active') {
            jsonResponse(403, 'error', 'Key không hợp lệ: ' . $key['status']);
        }

        // Cập nhật last_seen
        $this->db->execute(
            "UPDATE device_bindings SET last_seen_at = NOW() 
             WHERE key_id = ? AND device_identifier_hash = ? AND is_active = 1",
            [$key['id'], $deviceHash]
        );

        $iosVersion = sanitizeString($body['ios_version'] ?? '', 20);
        $iosCompat  = 'unsupported';
        if ($iosVersion) {
            $compat    = $this->db->fetchOne(
                "SELECT status FROM ios_compatibility WHERE ios_version = ? AND game_id IS NULL LIMIT 1",
                [$iosVersion]
            );
            $iosCompat = $compat['status'] ?? 'unsupported';
        }

        jsonResponse(200, 'success', 'Đã làm mới trạng thái.', [
            'key' => [
                'code'        => $keyCode,
                'status'      => $key['status'],
                'expires_at'  => $key['expires_at'],
                'is_lifetime' => $key['expires_at'] === null,
            ],
            'ios_compatible' => $iosCompat,
        ]);
    }

    /**
     * POST /api/v1/auth/unbind (yêu cầu admin token trong header)
     */
    public function unbind(): never
    {
        // Endpoint này chỉ dùng nội bộ / admin — kiểm tra token
        jsonResponse(403, 'error', 'Chức năng này chỉ thực hiện qua trang quản trị.');
    }

    // ─── Private Helpers ──────────────────────────────────────────────────────

    private function getConfig(string $key, mixed $default = null): mixed
    {
        $row = $this->db->fetchOne(
            "SELECT config_value FROM app_config WHERE config_key = ? LIMIT 1",
            [$key]
        );
        return $row ? $row['config_value'] : $default;
    }

    private function maskDeviceId(string $deviceId): string
    {
        // Chỉ lưu 8 ký tự đầu và 4 ký tự cuối để có thể debug nhưng không lộ full ID
        $len = strlen($deviceId);
        if ($len <= 12) return str_repeat('*', $len);
        return substr($deviceId, 0, 8) . str_repeat('*', $len - 12) . substr($deviceId, -4);
    }

    private function logActivity(
        string $actorType,
        ?int   $actorId,
        string $action,
        string $targetType,
        ?int   $targetId,
        string $targetLabel
    ): void {
        try {
            $this->db->insert(
                "INSERT INTO activity_logs (actor_type, actor_id, action, target_type, target_id, target_label, ip_address) 
                 VALUES (?, ?, ?, ?, ?, ?, ?)",
                [$actorType, $actorId, $action, $targetType, $targetId, $targetLabel, getClientIp()]
            );
        } catch (\Throwable) {
            // Log silently — không ảnh hưởng response
        }
    }
}
