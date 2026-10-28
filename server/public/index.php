<?php
/**
 * ZEV API — Bootstrap / Router
 * Tất cả request đến /api/v1/ đi qua file này
 */

declare(strict_types=1);

// ─── Autoload & Config ───────────────────────────────────────────────────────
define('ZEV_ROOT', dirname(__DIR__));
define('ZEV_START', microtime(true));

require_once ZEV_ROOT . '/src/helpers.php';
require_once ZEV_ROOT . '/src/Config/Database.php';
require_once ZEV_ROOT . '/src/Middleware/RateLimiter.php';
require_once ZEV_ROOT . '/src/Middleware/ApiAuth.php';
require_once ZEV_ROOT . '/src/Controllers/KeyController.php';
require_once ZEV_ROOT . '/src/Controllers/AppController.php';
require_once ZEV_ROOT . '/src/Controllers/FileController.php';
require_once ZEV_ROOT . '/src/Controllers/GameController.php';

use Zev\Middleware\RateLimiter;
use Zev\Middleware\ApiAuth;
use Zev\Controllers\KeyController;
use Zev\Controllers\AppController;
use Zev\Controllers\FileController;
use Zev\Controllers\GameController;

// ─── CORS & Headers ──────────────────────────────────────────────────────────
$config = require ZEV_ROOT . '/config/config.php';
$origin = $_SERVER['HTTP_ORIGIN'] ?? '*';

header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-API-Key, X-Device-ID, X-App-Version');
header('X-Content-Type-Options: nosniff');
header('X-Frame-Options: DENY');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}

// ─── Rate Limiting ────────────────────────────────────────────────────────────
$clientIp = getClientIp();
$rateLimiter = new RateLimiter();

if ($rateLimiter->isBlocked($clientIp, $_SERVER['REQUEST_URI'] ?? '/')) {
    jsonResponse(429, 'error', 'Quá nhiều yêu cầu. Vui lòng thử lại sau.');
}

// ─── Routing ──────────────────────────────────────────────────────────────────
$requestUri  = parse_url($_SERVER['REQUEST_URI'] ?? '/', PHP_URL_PATH);
$method      = $_SERVER['REQUEST_METHOD'];

// Strip /api/v1 prefix
$route = preg_replace('#^/api/v1#', '', $requestUri);
$route = rtrim($route, '/') ?: '/';

// Parse path segments
$segments = array_values(array_filter(explode('/', $route)));

try {
    match (true) {
        // POST /api/v1/auth/verify
        $method === 'POST' && $route === '/auth/verify'
            => (new KeyController())->verify(),

        // POST /api/v1/auth/refresh
        $method === 'POST' && $route === '/auth/refresh'
            => (new KeyController())->refresh(),

        // POST /api/v1/auth/unbind
        $method === 'POST' && $route === '/auth/unbind'
            => (new KeyController())->unbind(),

        // GET /api/v1/app/config
        $method === 'GET' && $route === '/app/config'
            => (new AppController())->config(),

        // GET /api/v1/app/version
        $method === 'GET' && $route === '/app/version'
            => (new AppController())->version(),

        // GET /api/v1/games
        $method === 'GET' && $route === '/games'
            => (new GameController())->index(),

        // GET /api/v1/games/{id}/categories
        $method === 'GET' && preg_match('#^/games/(\d+)/categories$#', $route, $m)
            => (new GameController())->categories((int)$m[1]),

        // GET /api/v1/games/{id}/features
        $method === 'GET' && preg_match('#^/games/(\d+)/features$#', $route, $m)
            => (new GameController())->features((int)$m[1]),

        // GET /api/v1/features/{id}
        $method === 'GET' && preg_match('#^/features/(\d+)$#', $route, $m)
            => (new GameController())->feature((int)$m[1]),

        // GET /api/v1/files/{id}/metadata
        $method === 'GET' && preg_match('#^/files/(\d+)/metadata$#', $route, $m)
            => (new FileController())->metadata((int)$m[1]),

        // POST /api/v1/files/{id}/request-download
        $method === 'POST' && preg_match('#^/files/(\d+)/request-download$#', $route, $m)
            => (new FileController())->requestDownload((int)$m[1]),

        // GET /api/v1/files/download/{token}
        $method === 'GET' && preg_match('#^/files/download/([a-zA-Z0-9_\-]+)$#', $route, $m)
            => (new FileController())->download($m[1]),

        // POST /api/v1/log/error
        $method === 'POST' && $route === '/log/error'
            => (new AppController())->logError(),

        default => jsonResponse(404, 'error', 'Endpoint không tồn tại.')
    };
} catch (\Throwable $e) {
    $debug = $config['app']['debug'] ?? false;
    $msg   = $debug ? $e->getMessage() : 'Lỗi máy chủ nội bộ.';
    error_log('[ZEV API] ' . $e->getMessage() . ' in ' . $e->getFile() . ':' . $e->getLine());
    jsonResponse(500, 'error', $msg);
}
