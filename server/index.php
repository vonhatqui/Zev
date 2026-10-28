<?php
declare(strict_types=1);

/**
 * ZEV Root Gateway
 * Điều hướng request từ cPanel public_html:
 * - /api/... -> Chuyển vào public/index.php xử lý API
 * - Trang chủ / -> Chuyển hướng sang trang quản trị /admin/
 */

$requestUri = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);

if (str_starts_with($requestUri, '/api/')) {
    require_once __DIR__ . '/public/index.php';
    exit;
}

header('Location: /admin/');
exit;
