<?php
/**
 * ZEV Admin — Nhật ký Hệ thống (Logs)
 */

define('ZEV_ROOT', dirname(__DIR__, 2));
require_once ZEV_ROOT . '/src/helpers.php';
require_once ZEV_ROOT . '/src/Config/Database.php';
require_once ZEV_ROOT . '/src/Auth/AdminAuth.php';

use Zev\Config\Database;
use Zev\Auth\AdminAuth;

AdminAuth::requireAuth();

$db = Database::getInstance();

// Xóa log nếu yêu cầu
if (isset($_POST['clear_logs'])) {
    $db->execute("TRUNCATE TABLE api_logs");
    $db->execute("TRUNCATE TABLE error_logs");
    header("Location: /admin/logs/");
    exit;
}

// Lấy danh sách log mới nhất
$type = sanitize($_GET['type'] ?? 'activation');

if ($type === 'errors') {
    $logs = $db->fetchAll("SELECT * FROM error_logs ORDER BY id DESC LIMIT 100");
} else {
    $logs = $db->fetchAll("
        SELECT l.*, k.key_code 
        FROM api_logs l 
        LEFT JOIN activation_keys k ON l.key_id = k.id 
        ORDER BY l.id DESC 
        LIMIT 100
    ");
}

$pageTitle = 'Nhật ký Hệ thống';
$activePage = 'logs';
require_once ZEV_ROOT . '/admin/partials/header.php';
?>

<div class="page-header" style="margin-bottom: 24px; display: flex; justify-content: space-between; align-items: center;">
  <div>
    <h1 style="font-size: 1.5rem; font-weight: 700; color: #fff; margin-bottom: 4px;">Nhật ký Hoạt động (Logs)</h1>
    <p style="color: var(--color-text-muted); font-size: 0.9rem;">
      Theo dõi yêu cầu xác thực API, thiết bị kích hoạt và lỗi phát sinh từ ứng dụng.
    </p>
  </div>
  <form method="POST" onsubmit="return confirm('Bạn chắc chắn muốn xóa toàn bộ log?');">
    <button type="submit" name="clear_logs" class="btn btn-sm" style="background: rgba(239, 68, 68, 0.15); color: #ef4444;">
      🗑️ Xóa sạch Log
    </button>
  </form>
</div>

<!-- Tabs -->
<div style="display: flex; gap: 12px; margin-bottom: 20px;">
  <a href="?type=activation" class="btn btn-sm <?= $type !== 'errors' ? 'btn-primary' : '' ?>" style="<?= $type === 'errors' ? 'background: var(--color-surface2); color: var(--color-text-muted);' : '' ?>">
    ⚡ API & Kích hoạt (100 gần nhất)
  </a>
  <a href="?type=errors" class="btn btn-sm <?= $type === 'errors' ? 'btn-primary' : '' ?>" style="<?= $type !== 'errors' ? 'background: var(--color-surface2); color: var(--color-text-muted);' : '' ?>">
    ⚠️ Lỗi Ứng dụng & Server (Errors)
  </a>
</div>

<!-- Log Table -->
<div class="card" style="padding: 0; overflow: hidden;">
  <div class="table-responsive">
    <table class="table" style="width: 100%; border-collapse: collapse;">
      <thead>
        <tr style="border-bottom: 1px solid var(--color-border); background: rgba(255,255,255,0.02); text-align: left;">
          <?php if ($type === 'errors'): ?>
            <th style="padding: 14px 16px;">Thời gian</th>
            <th style="padding: 14px 16px;">Thông báo lỗi</th>
            <th style="padding: 14px 16px;">File / Dòng</th>
            <th style="padding: 14px 16px;">IP Client</th>
          <?php else: ?>
            <th style="padding: 14px 16px;">Thời gian</th>
            <th style="padding: 14px 16px;">Endpoint</th>
            <th style="padding: 14px 16px;">Key / Thiết bị</th>
            <th style="padding: 14px 16px;">IP Address</th>
            <th style="padding: 14px 16px;">Mã phản hồi</th>
            <th style="padding: 14px 16px;">Trạng thái</th>
          <?php endif; ?>
        </tr>
      </thead>
      <tbody>
        <?php if (empty($logs)): ?>
          <tr>
            <td colspan="<?= $type === 'errors' ? 4 : 6 ?>" style="padding: 32px; text-align: center; color: var(--color-text-muted);">
              Không có dữ liệu nhật ký nào.
            </td>
          </tr>
        <?php else: ?>
          <?php foreach ($logs as $log): ?>
            <tr style="border-bottom: 1px solid rgba(255,255,255,0.05); font-size: 0.88rem;">
              <?php if ($type === 'errors'): ?>
                <td style="padding: 12px 16px; color: var(--color-text-muted); white-space: nowrap;">
                  <?= date('d/m H:i:s', strtotime($log['created_at'])) ?>
                </td>
                <td style="padding: 12px 16px; color: #f87171; font-weight: 500;">
                  <?= htmlspecialchars($log['error_message']) ?>
                </td>
                <td style="padding: 12px 16px; font-family: monospace; font-size: 0.8rem; color: var(--color-text-muted);">
                  <?= htmlspecialchars($log['file_location'] ?? '-') ?>
                </td>
                <td style="padding: 12px 16px; font-family: monospace; color: var(--color-text-muted);">
                  <?= htmlspecialchars($log['ip_address'] ?? '-') ?>
                </td>
              <?php else: ?>
                <td style="padding: 12px 16px; color: var(--color-text-muted); white-space: nowrap;">
                  <?= date('d/m H:i:s', strtotime($log['created_at'])) ?>
                </td>
                <td style="padding: 12px 16px; font-family: monospace;">
                  <span class="badge" style="background: rgba(108, 99, 255, 0.15); color: #8b83ff; font-size: 0.75rem;">
                    <?= htmlspecialchars($log['method'] ?? 'GET') ?>
                  </span>
                  <?= htmlspecialchars($log['endpoint'] ?? '/') ?>
                </td>
                <td style="padding: 12px 16px;">
                  <?php if (!empty($log['key_code'])): ?>
                    <span style="font-family: monospace; font-weight: 600; color: #a78bfa;"><?= htmlspecialchars($log['key_code']) ?></span>
                  <?php endif; ?>
                  <?php if (!empty($log['device_id'])): ?>
                    <div style="font-size: 0.75rem; color: var(--color-text-muted); font-family: monospace;">
                      HWID: <?= htmlspecialchars(substr($log['device_id'], 0, 16)) ?>...
                    </div>
                  <?php endif; ?>
                </td>
                <td style="padding: 12px 16px; font-family: monospace; color: var(--color-text-muted);">
                  <?= htmlspecialchars($log['ip_address'] ?? '-') ?>
                </td>
                <td style="padding: 12px 16px; font-family: monospace;">
                  <?php 
                    $code = (int)($log['response_code'] ?? 200);
                    $color = ($code >= 200 && $code < 300) ? '#22c55e' : (($code >= 400 && $code < 500) ? '#f59e0b' : '#ef4444');
                  ?>
                  <span style="color: <?= $color ?>; font-weight: 600;"><?= $code ?></span>
                </td>
                <td style="padding: 12px 16px;">
                  <?php if ($code >= 200 && $code < 300): ?>
                    <span class="badge" style="background: rgba(34, 197, 94, 0.15); color: #22c55e;">Thành công</span>
                  <?php else: ?>
                    <span class="badge" style="background: rgba(239, 68, 68, 0.15); color: #ef4444;">Từ chối</span>
                  <?php endif; ?>
                </td>
              <?php endif; ?>
            </tr>
          <?php endforeach; ?>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>

<?php require_once ZEV_ROOT . '/admin/partials/footer.php'; ?>
