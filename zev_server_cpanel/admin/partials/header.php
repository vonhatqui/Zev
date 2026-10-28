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
    ['id' => 'dashboard', 'label' => 'Dashboard',             'icon' => '<i class="fa-solid fa-chart-line"></i>',      'href' => '/admin/'],
    ['id' => 'keys',      'label' => 'Quản lý Key',           'icon' => '<i class="fa-solid fa-key"></i>',             'href' => '/admin/keys/'],
    ['id' => 'features',  'label' => 'Quản lý Bản Vá & File', 'icon' => '<i class="fa-solid fa-sliders"></i>',         'href' => '/admin/features/'],
    ['id' => 'app',       'label' => 'Cấu hình App',          'icon' => '<i class="fa-solid fa-gear"></i>',            'href' => '/admin/app/'],
    ['id' => 'files',     'label' => 'Kho File Tải',          'icon' => '<i class="fa-solid fa-box-archive"></i>',     'href' => '/admin/files/'],
    ['id' => 'logs',      'label' => 'Nhật ký Hoạt động',     'icon' => '<i class="fa-solid fa-clipboard-list"></i>', 'href' => '/admin/logs/'],
];
?>
<!DOCTYPE html>
<html lang="vi">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><?= htmlspecialchars($pageTitle ?? 'Admin') ?> — Zev Admin</title>
  <meta name="robots" content="noindex, nofollow">
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css">
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
        <i class="fa-solid fa-arrow-right-from-bracket"></i> Đăng xuất
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
