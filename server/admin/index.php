<?php
/**
 * ZEV Admin — Dashboard
 */

define('ZEV_ROOT', dirname(__DIR__));
require_once ZEV_ROOT . '/src/helpers.php';
require_once ZEV_ROOT . '/src/Config/Database.php';
require_once ZEV_ROOT . '/src/Auth/AdminAuth.php';

use Zev\Auth\AdminAuth;
use Zev\Config\Database;

AdminAuth::requireLogin();

$db = Database::getInstance();

// Thống kê
$keyStats = $db->fetchOne("
    SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN status = 'active' AND (expires_at IS NULL OR expires_at > NOW()) THEN 1 ELSE 0 END) as active,
        SUM(CASE WHEN status = 'expired' OR (status = 'active' AND expires_at IS NOT NULL AND expires_at <= NOW()) THEN 1 ELSE 0 END) as expired,
        SUM(CASE WHEN status = 'revoked' THEN 1 ELSE 0 END) as revoked,
        SUM(CASE WHEN status = 'suspended' THEN 1 ELSE 0 END) as suspended
    FROM activation_keys
");

$deviceCount = $db->fetchOne("SELECT COUNT(*) as cnt FROM device_bindings WHERE is_active = 1");
$fileCount   = $db->fetchOne("SELECT COUNT(*) as cnt, COALESCE(SUM(file_size),0) as total_size FROM file_records WHERE status = 'active'");

// Hoạt động gần đây
$recentLogs = $db->fetchAll("
    SELECT action, target_label, actor_label, ip_address, created_at
    FROM activity_logs
    ORDER BY created_at DESC
    LIMIT 10
");

// Keys sắp hết hạn (7 ngày tới)
$expiringKeys = $db->fetchAll("
    SELECT key_code, expires_at, status
    FROM activation_keys
    WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at BETWEEN NOW() AND DATE_ADD(NOW(), INTERVAL 7 DAY)
    ORDER BY expires_at ASC
    LIMIT 5
");

$pageTitle  = 'Dashboard';
$activePage = 'dashboard';
require_once __DIR__ . '/partials/header.php';
?>

<div class="stats-grid">
  <div class="stat-card primary">
    <div class="stat-icon">🔑</div>
    <div class="stat-value"><?= number_format($keyStats['total'] ?? 0) ?></div>
    <div class="stat-label">Tổng số Key</div>
  </div>
  <div class="stat-card success">
    <div class="stat-icon">✅</div>
    <div class="stat-value"><?= number_format($keyStats['active'] ?? 0) ?></div>
    <div class="stat-label">Key đang hoạt động</div>
  </div>
  <div class="stat-card warning">
    <div class="stat-icon">⏰</div>
    <div class="stat-value"><?= number_format($keyStats['expired'] ?? 0) ?></div>
    <div class="stat-label">Key hết hạn</div>
  </div>
  <div class="stat-card danger">
    <div class="stat-icon">🚫</div>
    <div class="stat-value"><?= number_format($keyStats['revoked'] ?? 0) ?></div>
    <div class="stat-label">Key bị thu hồi</div>
  </div>
  <div class="stat-card info">
    <div class="stat-icon">📱</div>
    <div class="stat-value"><?= number_format($deviceCount['cnt'] ?? 0) ?></div>
    <div class="stat-label">Thiết bị đã liên kết</div>
  </div>
  <div class="stat-card primary">
    <div class="stat-icon">📦</div>
    <div class="stat-value"><?= number_format($fileCount['cnt'] ?? 0) ?></div>
    <div class="stat-label">File đang hoạt động</div>
  </div>
</div>

<div style="display:grid; grid-template-columns: 1fr 1fr; gap:20px; margin-bottom:20px;">

  <!-- Recent Activity -->
  <div class="card">
    <div class="card-header">
      <span class="card-title">📋 Hoạt động gần đây</span>
      <a href="/admin/logs/" class="btn btn-secondary btn-sm">Xem tất cả</a>
    </div>
    <div class="table-wrap">
      <table class="data-table">
        <thead>
          <tr>
            <th>Hành động</th>
            <th>Đối tượng</th>
            <th>Thời gian</th>
          </tr>
        </thead>
        <tbody>
          <?php if (empty($recentLogs)): ?>
          <tr><td colspan="3" style="text-align:center; color:var(--color-text-dim); padding:24px;">Chưa có hoạt động</td></tr>
          <?php else: ?>
          <?php foreach ($recentLogs as $log): ?>
          <tr>
            <td><code style="font-size:0.78rem; color:var(--color-primary);"><?= htmlspecialchars($log['action']) ?></code></td>
            <td style="color:var(--color-text-muted); font-size:0.82rem;"><?= htmlspecialchars($log['target_label'] ?? '—') ?></td>
            <td style="color:var(--color-text-dim); font-size:0.78rem;" title="<?= $log['created_at'] ?>"><?= timeAgo($log['created_at']) ?></td>
          </tr>
          <?php endforeach; ?>
          <?php endif; ?>
        </tbody>
      </table>
    </div>
  </div>

  <!-- Expiring Keys -->
  <div class="card">
    <div class="card-header">
      <span class="card-title">⏰ Key sắp hết hạn (7 ngày)</span>
      <a href="/admin/keys/" class="btn btn-secondary btn-sm">Quản lý Key</a>
    </div>
    <div class="card-body">
      <?php if (empty($expiringKeys)): ?>
      <div class="empty-state" style="padding:24px 0;">
        <div style="font-size:2rem; margin-bottom:8px;">✅</div>
        <p style="font-size:0.85rem; color:var(--color-text-muted);">Không có key nào sắp hết hạn</p>
      </div>
      <?php else: ?>
      <?php foreach ($expiringKeys as $key): ?>
      <div style="display:flex; align-items:center; justify-content:space-between; padding:10px 0; border-bottom:1px solid var(--color-border);">
        <span class="key-display" onclick="copyText('<?= htmlspecialchars($key['key_code']) ?>')"><?= htmlspecialchars($key['key_code']) ?></span>
        <span style="font-size:0.8rem; color:var(--color-warning);">
          <?= date('d/m/Y', strtotime($key['expires_at'])) ?>
        </span>
      </div>
      <?php endforeach; ?>
      <?php endif; ?>
    </div>
  </div>

</div>

<!-- Quick Actions -->
<div class="card">
  <div class="card-header">
    <span class="card-title">⚡ Thao tác nhanh</span>
  </div>
  <div class="card-body" style="display:flex; gap:12px; flex-wrap:wrap;">
    <a href="/admin/keys/create.php" class="btn btn-primary">🔑 Tạo Key mới</a>
    <a href="/admin/files/upload.php" class="btn btn-secondary">📦 Tải file lên</a>
    <a href="/admin/app/config.php" class="btn btn-secondary">⚙️ Cấu hình App</a>
    <a href="/admin/app/features.php" class="btn btn-secondary">🎮 Quản lý tính năng</a>
  </div>
</div>

<?php
function timeAgo(string $datetime): string {
    $diff = time() - strtotime($datetime);
    if ($diff < 60)     return 'Vừa xong';
    if ($diff < 3600)   return floor($diff/60) . ' phút trước';
    if ($diff < 86400)  return floor($diff/3600) . ' giờ trước';
    return floor($diff/86400) . ' ngày trước';
}

require_once __DIR__ . '/partials/footer.php';
?>
