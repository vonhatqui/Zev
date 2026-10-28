<?php
/**
 * ZEV Admin — Trang đăng nhập
 */

define('ZEV_ROOT', dirname(__DIR__));
require_once ZEV_ROOT . '/src/helpers.php';
require_once ZEV_ROOT . '/src/Config/Database.php';
require_once ZEV_ROOT . '/src/Auth/AdminAuth.php';

use Zev\Auth\AdminAuth;

AdminAuth::init();

// Redirect nếu đã đăng nhập
if (!empty($_SESSION['admin_id'])) {
    header('Location: /admin/');
    exit;
}

$error   = '';
$success = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = sanitizeString($_POST['username'] ?? '');
    $password = $_POST['password'] ?? '';

    if (empty($username) || empty($password)) {
        $error = 'Vui lòng nhập đầy đủ tên đăng nhập và mật khẩu.';
    } else {
        $result = AdminAuth::login($username, $password, getClientIp());
        if ($result['success']) {
            header('Location: /admin/');
            exit;
        } else {
            $error = $result['message'];
        }
    }
}
?>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Đăng nhập — Zev Admin</title>
  <meta name="robots" content="noindex, nofollow">
  <link rel="stylesheet" href="/admin/assets/css/admin.css">
  <style>
    .login-form-title {
      font-size: 1rem;
      font-weight: 600;
      margin-bottom: 24px;
      color: var(--color-text-muted);
      text-align: center;
    }
    .login-btn {
      width: 100%;
      justify-content: center;
      margin-top: 8px;
      padding: 11px;
      font-size: 0.95rem;
    }
    .password-toggle {
      position: absolute;
      right: 12px;
      top: 50%;
      transform: translateY(-50%);
      background: none;
      border: none;
      color: var(--color-text-dim);
      cursor: pointer;
      padding: 4px;
    }
    .input-wrap { position: relative; }
  </style>
</head>
<body>
<div class="login-page">
  <div class="login-card">

    <div class="login-logo">
      <img src="/admin/assets/images/logo.png" alt="Zev Logo" onerror="this.src='https://files.catbox.moe/kony5d.png'">
      <h1>Zev Admin</h1>
      <p>Hệ thống quản trị server</p>
    </div>

    <?php if ($error): ?>
    <div class="alert alert-danger" id="error-alert">
      <span>⚠️</span>
      <span><?= htmlspecialchars($error) ?></span>
    </div>
    <?php endif; ?>

    <p class="login-form-title">Đăng nhập để tiếp tục</p>

    <form method="POST" id="loginForm" autocomplete="off">
      <div class="form-group">
        <label class="form-label" for="username">Tên đăng nhập</label>
        <input
          type="text"
          id="username"
          name="username"
          class="form-control"
          placeholder="admin"
          value="<?= htmlspecialchars($_POST['username'] ?? '') ?>"
          required
          autocomplete="username"
          autofocus
        >
      </div>

      <div class="form-group">
        <label class="form-label" for="password">Mật khẩu</label>
        <div class="input-wrap">
          <input
            type="password"
            id="password"
            name="password"
            class="form-control"
            placeholder="••••••••"
            required
            autocomplete="current-password"
            style="padding-right: 42px;"
          >
          <button type="button" class="password-toggle" id="togglePass" title="Hiện/ẩn mật khẩu">
            👁️
          </button>
        </div>
      </div>

      <button type="submit" class="btn btn-primary login-btn" id="submitBtn">
        <span id="btnText">Đăng nhập</span>
        <span id="btnSpinner" style="display:none">⏳</span>
      </button>
    </form>

    <p style="text-align:center; margin-top:24px; font-size:0.78rem; color:var(--color-text-dim);">
      Zev Admin Panel v1.0
    </p>
  </div>
</div>

<script>
  // Toggle password visibility
  document.getElementById('togglePass').addEventListener('click', function() {
    const input = document.getElementById('password');
    input.type = input.type === 'password' ? 'text' : 'password';
  });

  // Submit loading state
  document.getElementById('loginForm').addEventListener('submit', function() {
    const btn     = document.getElementById('submitBtn');
    const text    = document.getElementById('btnText');
    const spinner = document.getElementById('btnSpinner');
    btn.disabled  = true;
    text.textContent = 'Đang xử lý...';
    spinner.style.display = 'inline';
  });
</script>
</body>
</html>
