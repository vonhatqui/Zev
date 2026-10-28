<?php
/**
 * ZEV — Helper Functions
 */

/**
 * Trả về JSON response và thoát (hỗ trợ cả cú pháp jsonResponse(code, status, msg, data) và jsonResponse(array, code))
 */
function jsonResponse($httpCodeOrData, $status = 'success', string $message = '', array $data = []): never
{
    if (is_array($httpCodeOrData)) {
        $code = (is_int($status) || is_numeric($status)) ? (int)$status : 200;
        http_response_code($code);
        echo json_encode($httpCodeOrData, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        exit;
    }

    http_response_code((int)$httpCodeOrData);
    $body = [
        'status'  => (string)$status,
        'message' => $message,
    ];
    if (!empty($data)) {
        $body['data'] = $data;
    }
    echo json_encode($body, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}

/**
 * Lấy dữ liệu JSON từ request body
 */
function getJsonBody(): array
{
    $raw = file_get_contents('php://input');
    if (empty($raw)) return [];
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : [];
}

/**
 * Lấy IP client thực (qua proxy/CDN)
 */
function getClientIp(): string
{
    $headers = [
        'HTTP_CF_CONNECTING_IP',  // Cloudflare
        'HTTP_X_REAL_IP',
        'HTTP_X_FORWARDED_FOR',
        'REMOTE_ADDR',
    ];
    foreach ($headers as $h) {
        if (!empty($_SERVER[$h])) {
            $ip = trim(explode(',', $_SERVER[$h])[0]);
            if (filter_var($ip, FILTER_VALIDATE_IP)) {
                return $ip;
            }
        }
    }
    return '0.0.0.0';
}

/**
 * Sanitize string input
 */
function sanitizeString(?string $value, int $maxLength = 255): string
{
    if ($value === null) return '';
    return mb_substr(trim(strip_tags($value)), 0, $maxLength);
}

function sanitize(?string $value, int $maxLength = 255): string
{
    return sanitizeString($value, $maxLength);
}

/**
 * Định dạng dung lượng bytes sang KB, MB, GB
 */
function formatBytes(int $bytes, int $precision = 2): string
{
    $units = ['B', 'KB', 'MB', 'GB', 'TB'];
    $bytes = max($bytes, 0);
    $pow = floor(($bytes ? log($bytes) : 0) / log(1024));
    $pow = min($pow, count($units) - 1);
    $bytes /= pow(1024, $pow);
    return round($bytes, $precision) . ' ' . $units[$pow];
}

/**
 * Tạo token ngẫu nhiên an toàn
 */
function generateToken(int $bytes = 32): string
{
    return bin2hex(random_bytes($bytes));
}

/**
 * Hash device identifier
 */
function hashDeviceId(string $deviceId): string
{
    return hash('sha256', 'zev_device_' . $deviceId);
}

/**
 * Kiểm tra key format: ZEV-XXXX-XXXX-XXXX
 */
function isValidKeyFormat(string $key): bool
{
    return (bool) preg_match('/^[A-Z0-9]{3,6}-[A-Z0-9]{4,8}-[A-Z0-9]{4,8}-[A-Z0-9]{4,8}$/i', $key);
}
