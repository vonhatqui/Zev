<?php
/**
 * ZEV Server — Cấu hình mẫu
 * 
 * SAO CHÉP file này thành config.php và điền thông tin thực tế.
 * KHÔNG commit config.php lên Git.
 * KHÔNG để lộ thông tin trong config.php.
 */

return [
    // ----------------------------------------------------------------
    // Database
    // ----------------------------------------------------------------
    'db' => [
        'host'     => 'localhost',
        'port'     => 3306,
        'name'     => 'YOUR_DATABASE_NAME',
        'user'     => 'YOUR_DATABASE_USER',
        'password' => 'YOUR_DATABASE_PASSWORD',
        'charset'  => 'utf8mb4',
    ],

    // ----------------------------------------------------------------
    // Application
    // ----------------------------------------------------------------
    'app' => [
        'name'        => 'Zev',
        'version'     => '1.0.0',
        'env'         => 'production',   // 'development' | 'production'
        'debug'       => false,          // KHÔNG bật trên production
        'timezone'    => 'Asia/Ho_Chi_Minh',
        'base_url'    => 'https://YOUR_DOMAIN.sbs',  // Không có dấu /
    ],

    // ----------------------------------------------------------------
    // Security
    // ----------------------------------------------------------------
    'security' => [
        // JWT secret — tạo bằng: php -r "echo bin2hex(random_bytes(32));"
        'jwt_secret'      => 'CHANGE_THIS_TO_A_RANDOM_64_CHAR_HEX_STRING',
        'jwt_ttl_seconds' => 3600,  // 1 giờ

        // Session
        'session_name'    => 'zev_admin_session',
        'session_lifetime'=> 7200,  // 2 giờ

        // CORS — danh sách origin được phép (iOS app dùng HTTPS)
        'allowed_origins' => ['*'],  // Thay bằng domain cụ thể trên production

        // Rate limiting
        'rate_limit_requests_per_minute' => 30,
        'rate_limit_block_minutes'       => 15,
    ],

    // ----------------------------------------------------------------
    // File Storage
    // ----------------------------------------------------------------
    'storage' => [
        // Đường dẫn tuyệt đối đến thư mục uploads
        // Phải nằm NGOÀI document root để không thể truy cập trực tiếp
        'upload_path'       => '/home/YOUR_CPANEL_USER/zev_uploads',
        'max_file_size_mb'  => 100,
        'allowed_extensions'=> ['3105', 'json', 'zip', 'bin'],

        // Thời hạn download token (giây)
        'download_token_ttl'=> 300,
    ],

    // ----------------------------------------------------------------
    // Admin
    // ----------------------------------------------------------------
    'admin' => [
        'session_key' => 'zev_admin_auth',
        'max_login_attempts' => 5,       // Số lần sai mật khẩu tối đa
        'lockout_minutes'    => 30,      // Khóa sau khi sai nhiều lần
    ],
];
