<?php
/**
 * ZEV — App Controller
 * Cấu hình ứng dụng, version check, error logging
 */

namespace Zev\Controllers;

use Zev\Config\Database;

class AppController
{
    private Database $db;
    private array $config;

    public function __construct()
    {
        $this->db     = Database::getInstance();
        $this->config = require ZEV_ROOT . '/config/config.php';
    }

    /**
     * GET /api/v1/app/config
     * Trả về cấu hình công khai của ứng dụng
     */
    public function config(): void
    {
        $rows = $this->db->fetchAll(
            "SELECT config_key, config_value FROM app_config WHERE is_public = 1"
        );

        $configMap = [];
        foreach ($rows as $row) {
            $configMap[$row['config_key']] = $row['config_value'];
        }

        // iOS compatibility list
        $iosCompatList = $this->db->fetchAll(
            "SELECT ios_version, status, note FROM ios_compatibility WHERE game_id IS NULL ORDER BY ios_version DESC"
        );

        jsonResponse(200, 'success', 'OK', [
            'config'           => $configMap,
            'ios_compatibility'=> $iosCompatList,
            'server_time'      => date('c'),
        ]);
    }

    /**
     * GET /api/v1/app/version
     * Kiểm tra phiên bản app, force update nếu cần
     */
    public function version(): void
    {
        $clientVersion  = sanitizeString($_GET['v'] ?? '', 20);
        $minVersion     = $this->getConfig('app_version_minimum', '1.0.0');
        $maintenance    = (bool) $this->getConfig('maintenance_mode', '0');
        $maintMsgVi     = $this->getConfig('maintenance_message_vi', '');
        $maintMsgEn     = $this->getConfig('maintenance_message_en', '');

        $forceUpdate    = false;
        if ($clientVersion && version_compare($clientVersion, $minVersion, '<')) {
            $forceUpdate = true;
        }

        jsonResponse(200, 'success', 'OK', [
            'minimum_version' => $minVersion,
            'force_update'    => $forceUpdate,
            'maintenance'     => $maintenance,
            'maintenance_message' => [
                'vi' => $maintMsgVi,
                'en' => $maintMsgEn,
            ],
        ]);
    }

    /**
     * POST /api/v1/log/error
     * Nhận lỗi từ iOS app
     */
    public function logError(): void
    {
        $body  = getJsonBody();
        $level = sanitizeString($body['level'] ?? 'error', 20);
        $msg   = sanitizeString($body['message'] ?? '', 500);
        $ctx   = json_encode($body['context'] ?? []);

        if (empty($msg)) {
            jsonResponse(400, 'error', 'Message không được rỗng.');
        }

        $allowedLevels = ['debug', 'info', 'warning', 'error', 'critical'];
        if (!in_array($level, $allowedLevels)) {
            $level = 'error';
        }

        try {
            $this->db->insert(
                "INSERT INTO activity_logs (actor_type, action, details, ip_address) VALUES ('api', ?, ?, ?)",
                ["client.log.{$level}", $ctx, getClientIp()]
            );
        } catch (\Throwable $e) {}

        jsonResponse(200, 'success', 'Đã ghi nhận lỗi.');
    }

    // ─── Private ─────────────────────────────────────────────────────────────

    private function getConfig(string $key, $default = null)
    {
        $row = $this->db->fetchOne(
            "SELECT config_value FROM app_config WHERE config_key = ? LIMIT 1",
            [$key]
        );
        return $row ? $row['config_value'] : $default;
    }
}
