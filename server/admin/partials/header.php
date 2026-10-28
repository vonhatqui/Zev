<?php
/**
 * ZEV Admin — Partial: Sidebar + Header layout
 * Include file này trong mỗi trang admin
 * 
 * Yêu cầu biến: $pageTitle, $activePage
 */

use Zev\Auth\AdminAuth;

$admin = AdminAuth::currentAdmin();
$adminName = $admin['display_name'] ?? $admin['username'] ?? 'Admin';
$adminRole = $admin['role'] ?? 'admin';
$adminInitial = strtoupper(substr($adminName, 0, 1));

$navItems = [
    ['id' => 'dashboard', 'label' => 'Dashboard',       'icon' => '📊', 'href' => '/admin/'],
    ['id' => 'keys',      'label' => 'Quản lý Key',     'icon' => '🔑', 'href' => '/admin/keys/'],
    ['id' => 'features',  'label' => 'Chức năng & File', 'icon' => '🎯', 'href' => '/admin/features/'],
    ['id' => 'app',       'label' => 'Cấu hình App',    'icon' => '⚙️', 'href' => '/admin/app/'],
    ['id' => 'files',     'label' => 'Kho File Tải',    'icon' => '📦', 'href' => '/admin/files/'],
    ['id' => 'logs',      'label' => 'Nhật ký',         'icon' => '📋', 'href' => '/admin/logs/'],
];
?>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><?= htmlspecialchars($pageTitle ?? 'Admin') ?> — Zev Admin</title>
  <meta name="robots" content="noindex, nofollow">
  <link rel="stylesheet" href="/admin/assets/css/admin.css">
  <?php if (isset($extraStyles)) echo $extraStyles; ?>
</head>
<body>
<div class="admin-layout">

  <!-- Sidebar -->
  <aside class="sidebar">
    <div class="sidebar-logo">
      <img src="/admin/assets/images/logo.png" alt="Zev" onerror="this.src='https://files.catbox.moe/kony5d.png'">
      <div>
        <div class="sidebar-logo-text">Zev</div>
        <div class="sidebar-logo-sub">Admin Panel</div>
      </div>
    </div>

    <nav class="sidebar-nav">
      <div class="nav-section-label">Điều hướng</div>
      <?php foreach ($navItems as $item): ?>
      <a class="nav-item <?= ($activePage ?? '') === $item['id'] ? 'active' : '' ?>"
         href="<?= $item['href'] ?>">
        <span class="nav-icon"><?= $item['icon'] ?></span>
        <span><?= $item['label'] ?></span>
      </a>
      <?php endforeach; ?>
    </nav>

    <div class="sidebar-footer">
      <div style="font-weight:600; color:var(--color-text-muted); margin-bottom:4px;">
        <?= htmlspecialchars($adminName) ?>
      </div>
      <div style="margin-bottom:10px;"><?= ucfirst($adminRole) ?></div>
      <a href="/admin/logout.php" style="color:var(--color-danger); font-size:0.8rem;">
        🚪 Đăng xuất
      </a>
    </div>
  </aside>

  <!-- Main -->
  <div class="main-content">
    <header class="top-header">
      <div class="page-title"><?= htmlspecialchars($pageTitle ?? '') ?></div>
      <div class="header-actions">
        <a href="/admin/keys/create.php" class="btn btn-primary btn-sm">+ Tạo Key</a>
        <div class="admin-badge">
          <div class="admin-avatar"><?= $adminInitial ?></div>
          <span><?= htmlspecialchars($adminName) ?></span>
        </div>
      </div>
    </header>

    <div class="page-content">
