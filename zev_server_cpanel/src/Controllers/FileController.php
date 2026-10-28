<?php
/**
 * ZEV — File Controller
 * Metadata và download token cho file
 */

namespace Zev\Controllers;

use Zev\Config\Database;

class FileController
{
    private Database $db;
    private array $config;

    public function __construct()
    {
        $this->db     = Database::getInstance();
        $this->config = require ZEV_ROOT . '/config/config.php';
    }

    /**
     * GET /api/v1/files/{id}/metadata
     * Yêu cầu xác thực: Header X-API-Key (key code) + X-Device-ID
     */
    public function metadata(int $fileId): void
    {
        $this->requireAuth();

        $file = $this->db->fetchOne(
            "SELECT id, display_name, file_size, mime_type, checksum_sha256, 
                    file_version, status, feature_type,
                    g.display_name as game_name
             FROM file_records fr
             LEFT JOIN games g ON g.id = fr.game_id
             WHERE fr.id = ? AND fr.status = 'active'",
            [$fileId]
        );

        if (!$file) {
            jsonResponse(404, 'error', 'File không tồn tại hoặc đã bị vô hiệu hóa.');
        }

        jsonResponse(200, 'success', 'OK', ['file' => $file]);
    }

    /**
     * POST /api/v1/files/{id}/request-download
     * Tạo download token có thời hạn
     */
    public function requestDownload(int $fileId): void
    {
        [$keyId, $deviceHash] = $this->requireAuth();

        $file = $this->db->fetchOne(
            "SELECT id, original_name, file_path, file_size, checksum_sha256, status 
             FROM file_records WHERE id = ? AND status = 'active'",
            [$fileId]
        );

        if (!$file) {
            jsonResponse(404, 'error', 'File không tồn tại hoặc đã bị vô hiệu hóa.');
        }

        $ttl    = (int) ($this->config['storage']['download_token_ttl'] ?? 300);
        $token  = generateToken(32);
        $expiry = date('Y-m-d H:i:s', time() + $ttl);

        $this->db->insert(
            "INSERT INTO download_tokens (token, file_id, key_id, device_hash, expires_at) VALUES (?, ?, ?, ?, ?)",
            [$token, $fileId, $keyId, $deviceHash, $expiry]
        );

        $baseUrl     = $this->config['app']['base_url'];
        $downloadUrl = "{$baseUrl}/api/v1/files/download/{$token}";

        jsonResponse(200, 'success', 'URL tải xuống đã được tạo.', [
            'download_url' => $downloadUrl,
            'expires_at'   => $expiry,
            'file_size'    => $file['file_size'],
            'checksum'     => $file['checksum_sha256'],
        ]);
    }

    /**
     * GET /api/v1/files/download/{token}
     * Stream file nếu token còn hạn
     */
    public function download(string $token): void
    {
        $token = preg_replace('/[^a-zA-Z0-9_\-]/', '', $token);

        $record = $this->db->fetchOne(
            "SELECT dt.*, fr.file_path, fr.original_name, fr.mime_type, fr.file_size
             FROM download_tokens dt
             JOIN file_records fr ON fr.id = dt.file_id
             WHERE dt.token = ? AND dt.used_at IS NULL AND dt.expires_at > NOW() AND fr.status = 'active'
             LIMIT 1",
            [$token]
        );

        if (!$record) {
            http_response_code(403);
            echo json_encode(['status' => 'error', 'message' => 'Link tải xuống không hợp lệ hoặc đã hết hạn.']);
            exit;
        }

        // Đánh dấu token đã dùng (single-use)
        $this->db->execute(
            "UPDATE download_tokens SET used_at = NOW() WHERE id = ?",
            [$record['id']]
        );

        $uploadPath = rtrim($this->config['storage']['upload_path'], '/');
        $filePath   = $uploadPath . '/' . ltrim($record['file_path'], '/');

        if (!file_exists($filePath) || !is_readable($filePath)) {
            http_response_code(404);
            echo json_encode(['status' => 'error', 'message' => 'File không tồn tại trên server.']);
            exit;
        }

        // Serve file
        header('Content-Type: ' . ($record['mime_type'] ?: 'application/octet-stream'));
        header('Content-Disposition: attachment; filename="' . rawurlencode($record['original_name']) . '"');
        header('Content-Length: ' . $record['file_size']);
        header('Cache-Control: no-store, no-cache');
        header('X-Content-Type-Options: nosniff');

        readfile($filePath);
        exit;
    }

    // ─── Private ─────────────────────────────────────────────────────────────

    /**
     * Xác thực API request — trả về [keyId, deviceHash]
     */
    private function requireAuth(): array
    {
        $apiKey    = $_SERVER['HTTP_X_API_KEY'] ?? '';
        $deviceId  = $_SERVER['HTTP_X_DEVICE_ID'] ?? '';

        if (empty($apiKey) || empty($deviceId)) {
            jsonResponse(401, 'error', 'Yêu cầu xác thực. Vui lòng kích hoạt key trước.');
        }

        $deviceHash = hashDeviceId($deviceId);

        $binding = $this->db->fetchOne(
            "SELECT db.key_id, db.device_identifier_hash
             FROM device_bindings db
             JOIN activation_keys ak ON ak.id = db.key_id
             WHERE ak.key_code = ? AND db.device_identifier_hash = ? AND db.is_active = 1
               AND ak.status = 'active' AND (ak.expires_at IS NULL OR ak.expires_at > NOW())
             LIMIT 1",
            [$apiKey, $deviceHash]
        );

        if (!$binding) {
            jsonResponse(403, 'error', 'Key không hợp lệ hoặc thiết bị không khớp.');
        }

        return [(int) $binding['key_id'], $deviceHash];
    }
}
