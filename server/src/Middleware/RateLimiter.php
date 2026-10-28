<?php
/**
 * ZEV — Rate Limiter Middleware
 */

namespace Zev\Middleware;

use Zev\Config\Database;

class RateLimiter
{
    private Database $db;
    private int $maxRequests;
    private int $windowSeconds = 60;
    private int $blockMinutes;

    public function __construct()
    {
        $this->db          = Database::getInstance();
        $config            = require ZEV_ROOT . '/config/config.php';
        $this->maxRequests = (int) ($config['security']['rate_limit_requests_per_minute'] ?? 30);
        $this->blockMinutes= 15;
    }

    public function isBlocked(string $identifier, string $endpoint): bool
    {
        $endpoint = $this->normalizeEndpoint($endpoint);

        // Kiểm tra đang bị block không
        $record = $this->db->fetchOne(
            "SELECT * FROM rate_limits WHERE identifier = ? AND endpoint = ? LIMIT 1",
            [$identifier, $endpoint]
        );

        if ($record && $record['blocked_until'] !== null) {
            if (strtotime($record['blocked_until']) > time()) {
                return true; // Vẫn đang bị block
            }
            // Block đã hết, reset
            $this->db->execute(
                "UPDATE rate_limits SET blocked_until = NULL, request_count = 0, window_start = NOW() 
                 WHERE identifier = ? AND endpoint = ?",
                [$identifier, $endpoint]
            );
            return false;
        }

        // Kiểm tra window
        if ($record) {
            $windowStart = strtotime($record['window_start']);
            if (time() - $windowStart > $this->windowSeconds) {
                // Window mới
                $this->db->execute(
                    "UPDATE rate_limits SET request_count = 1, window_start = NOW() 
                     WHERE identifier = ? AND endpoint = ?",
                    [$identifier, $endpoint]
                );
                return false;
            }

            $newCount = $record['request_count'] + 1;
            if ($newCount > $this->maxRequests) {
                $blockedUntil = date('Y-m-d H:i:s', time() + ($this->blockMinutes * 60));
                $this->db->execute(
                    "UPDATE rate_limits SET request_count = ?, blocked_until = ? 
                     WHERE identifier = ? AND endpoint = ?",
                    [$newCount, $blockedUntil, $identifier, $endpoint]
                );
                return true;
            }

            $this->db->execute(
                "UPDATE rate_limits SET request_count = ? WHERE identifier = ? AND endpoint = ?",
                [$newCount, $identifier, $endpoint]
            );
        } else {
            // Tạo record mới
            try {
                $this->db->insert(
                    "INSERT INTO rate_limits (identifier, endpoint, request_count, window_start) VALUES (?, ?, 1, NOW())",
                    [$identifier, $endpoint]
                );
            } catch (\Throwable) {}
        }

        return false;
    }

    private function normalizeEndpoint(string $uri): string
    {
        // Chuẩn hóa URI để gom nhóm các request tương tự
        $uri = parse_url($uri, PHP_URL_PATH) ?? $uri;
        // Thay thế số với placeholder
        $uri = preg_replace('/\/\d+/', '/{id}', $uri);
        return mb_substr($uri, 0, 128);
    }
}
