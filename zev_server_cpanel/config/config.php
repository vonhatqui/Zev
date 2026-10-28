<?php
/**
 * ZEV Server — Cấu hình chính thức
 * Tên miền: crackbomaydihihi.sbs
 * Hỗ trợ MySQL (cPanel) và SQLite tự động
 */

return [
    // ----------------------------------------------------------------
    // Database
    // ----------------------------------------------------------------
    'db' => [
        'driver'   => 'mysql', // 'mysql' hoặc 'sqlite'
        'host'     => 'localhost',
        'port'     => 3306,
        'name'     => 'zev_database',
        'user'     => 'zev_user',
        'password' => 'zev_password',
        'charset'  => 'utf8mb4',
        'path'     => __DIR__ . '/../database/zev.sqlite', // dùng khi driver = sqlite
    ],

    // ----------------------------------------------------------------
    // Application
    // ----------------------------------------------------------------
    'app' => [
        'name'        => 'Zev',
        'version'     => '1.0.0',
        'env'         => 'production',
        'debug'       => false,
        'timezone'    => 'Asia/Ho_Chi_Minh',
        'base_url'    => 'https://crackbomaydihihi.sbs',
    ],

    // ----------------------------------------------------------------
    // Security
    // ----------------------------------------------------------------
    'security' => [
        'jwt_secret'      => 'e4c89283fbb2201d7845fbb8912ce33a019485bb391823a019e09d12347fa65e',
        'jwt_ttl_seconds' => 86400 * 30, // 30 ngày
        'session_name'    => 'zev_admin_session',
        'session_lifetime'=> 86400 * 7,
        'allowed_origins' => ['*'],
        'rate_limit_requests_per_minute' => 60,
        'rate_limit_block_minutes'       => 10,
    ],

    // ----------------------------------------------------------------
    // File Storage
    // ----------------------------------------------------------------
    'storage' => [
        'upload_path'        => __DIR__ . '/../uploads/files',
        'max_file_size_mb'   => 250,
        'allowed_extensions' => ['3105', 'bytes', 'gzip', 'unityfs', 'json', 'plist', 'zip', 'dat', 'bin', 'config', 'txt'],
        'download_token_ttl' => 600, // 10 phút
    ],

    // ----------------------------------------------------------------
    // Admin
    // ----------------------------------------------------------------
    'admin' => [
        'session_key'        => 'zev_admin_auth',
        'max_login_attempts' => 10,
        'lockout_minutes'    => 15,
    ],
];
