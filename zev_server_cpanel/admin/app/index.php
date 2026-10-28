<?php
/**
 * ZEV Admin — Cấu hình Ứng dụng & Hệ thống
 */

define('ZEV_ROOT', dirname(__DIR__, 2));
require_once ZEV_ROOT . '/src/helpers.php';
require_once ZEV_ROOT . '/src/Config/Database.php';
require_once ZEV_ROOT . '/src/Auth/AdminAuth.php';

use Zev\Config\Database;
use Zev\Auth\AdminAuth;

AdminAuth::requireLogin();

$db = Database::getInstance();
$successMsg = '';
$errorMsg = '';

// Lưu cài đặt khi submit
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $configs = $_POST['config'] ?? [];

    try {
        foreach ($configs as $key => $value) {
            $key = sanitizeString($key);
            $value = trim($value);

            // Kiểm tra xem config đã có chưa
            $exists = $db->fetchOne("SELECT id FROM app_config WHERE config_key = ?", [$key]);
            if ($exists) {
                $db->execute("UPDATE app_config SET config_value = ?, updated_at = NOW() WHERE config_key = ?", [$value, $key]);
            } else {
                $db->execute("INSERT INTO app_config (config_key, config_value, updated_at) VALUES (?, ?, NOW())", [$key, $value]);
            }
        }
        $successMsg = "Cập nhật cấu hình thành công!";
    } catch (\Exception $e) {
        $errorMsg = "Lỗi khi lưu cấu hình: " . $e->getMessage();
    }
}

// Lấy danh sách cấu hình hiện tại
$rows = $db->fetchAll("SELECT config_key, config_value FROM app_config");
$currentConfig = [];
foreach ($rows as $r) {
    $currentConfig[$r['config_key']] = $r['config_value'];
}

$pageTitle = 'Cấu hình Ứng dụng';
$activePage = 'app';
require_once ZEV_ROOT . '/admin/partials/header.php';
?>

<div class="page-header" style="margin-bottom: 24px;">
  <div>
    <h1 style="font-size: 1.5rem; font-weight: 700; color: #fff; margin-bottom: 4px;">Cấu hình Hệ thống Zev</h1>
    <p style="color: var(--color-text-muted); font-size: 0.9rem;">
      Quản lý phiên bản ứng dụng, bảo trì, thông báo toàn hệ thống và kênh hỗ trợ.
    </p>
  </div>
</div>

<?php if ($successMsg): ?>
  <div class="alert alert-success" style="margin-bottom: 20px; padding: 12px 16px; border-radius: 8px; background: rgba(34, 197, 94, 0.15); border: 1px solid #22c55e; color: #4ade80;">
    ✓ <?= htmlspecialchars($successMsg) ?>
  </div>
<?php endif; ?>

<?php if ($errorMsg): ?>
  <div class="alert alert-danger" style="margin-bottom: 20px; padding: 12px 16px; border-radius: 8px; background: rgba(239, 68, 68, 0.15); border: 1px solid #ef4444; color: #f87171;">
    ✕ <?= htmlspecialchars($errorMsg) ?>
  </div>
<?php endif; ?>

<form method="POST" action="" style="display: flex; flex-direction: column; gap: 24px;">

  <!-- Card 1: Chế độ bảo trì -->
  <div class="card">
    <div class="card-header" style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 16px;">
      <h3 style="font-size: 1.1rem; color: #fff; font-weight: 600;">🛠️ Trạng thái Máy chủ & Bảo trì</h3>
    </div>
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
      <div class="form-group" style="grid-column: span 2;">
        <label style="display: block; margin-bottom: 8px; font-weight: 500;">Chế độ bảo trì ứng dụng (Maintenance Mode)</label>
        <select name="config[maintenance_mode]" class="form-control" style="max-width: 300px;">
          <option value="0" <?= ($currentConfig['maintenance_mode'] ?? '0') === '0' ? 'selected' : '' ?>>🟢 Hoạt động bình thường (Online)</option>
          <option value="1" <?= ($currentConfig['maintenance_mode'] ?? '0') === '1' ? 'selected' : '' ?>>🔴 Đang bảo trì (Tạm khóa app)</option>
        </select>
      </div>

      <div class="form-group">
        <label style="display: block; margin-bottom: 8px; font-weight: 500;">Thông báo bảo trì (Tiếng Việt)</label>
        <textarea name="config[maintenance_message_vi]" class="form-control" rows="3"><?= htmlspecialchars($currentConfig['maintenance_message_vi'] ?? 'Hệ thống Zev đang được nâng cấp máy chủ. Vui lòng quay lại sau ít phút.') ?></textarea>
      </div>

      <div class="form-group">
        <label style="display: block; margin-bottom: 8px; font-weight: 500;">Thông báo bảo trì (English)</label>
        <textarea name="config[maintenance_message_en]" class="form-control" rows="3"><?= htmlspecialchars($currentConfig['maintenance_message_en'] ?? 'Zev server is currently undergoing scheduled maintenance. Please check back soon.') ?></textarea>
      </div>
    </div>
  </div>

  <!-- Card 2: Quản lý Phiên bản iOS -->
  <div class="card">
    <div class="card-header" style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 16px;">
      <h3 style="font-size: 1.1rem; color: #fff; font-weight: 600;">📱 Quản lý Phiên bản iOS (Version & Update)</h3>
    </div>
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
      <div class="form-group">
        <label style="display: block; margin-bottom: 8px; font-weight: 500;">Phiên bản mới nhất (Latest Version)</label>
        <input type="text" name="config[app_latest_version]" class="form-control" value="<?= htmlspecialchars($currentConfig['app_latest_version'] ?? '1.0.0') ?>" placeholder="ví dụ: 1.0.1">
      </div>

      <div class="form-group">
        <label style="display: block; margin-bottom: 8px; font-weight: 500;">Phiên bản tối thiểu bắt buộc (Min Required Version)</label>
        <input type="text" name="config[app_min_version]" class="form-control" value="<?= htmlspecialchars($currentConfig['app_min_version'] ?? '1.0.0') ?>" placeholder="ví dụ: 1.0.0">
        <small style="color: var(--color-text-muted); font-size: 0.8rem;">Nếu client có phiên bản thấp hơn, app sẽ bắt buộc cập nhật.</small>
      </div>

      <div class="form-group" style="grid-column: span 2;">
        <label style="display: block; margin-bottom: 8px; font-weight: 500;">Đường link tải bản cập nhật / IPA Download URL</label>
        <input type="url" name="config[app_download_url]" class="form-control" value="<?= htmlspecialchars($currentConfig['app_download_url'] ?? '') ?>" placeholder="https://crackbomaydihihi.sbs/download/zev.ipa">
      </div>

      <div class="form-group" style="grid-column: span 2;">
        <label style="display: block; margin-bottom: 8px; font-weight: 500;">Nội dung cập nhật (Release Changelog)</label>
        <textarea name="config[update_changelog]" class="form-control" rows="3" placeholder="- Sửa lỗi kích hoạt key&#10;- Thêm tính năng game mới"><?= htmlspecialchars($currentConfig['update_changelog'] ?? '') ?></textarea>
      </div>
    </div>
  </div>

  <!-- Card 3: Thông báo & Kênh hỗ trợ -->
  <div class="card">
    <div class="card-header" style="border-bottom: 1px solid var(--color-border); padding-bottom: 12px; margin-bottom: 16px;">
      <h3 style="font-size: 1.1rem; color: #fff; font-weight: 600;">📢 Thông báo & Kênh Hỗ trợ</h3>
    </div>
    <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 16px;">
      <div class="form-group" style="grid-column: span 2;">
        <label style="display: block; margin-bottom: 8px; font-weight: 500;">Thông báo nổi bật (Banner Announcement)</label>
        <input type="text" name="config[announcement_text]" class="form-control" value="<?= htmlspecialchars($currentConfig['announcement_text'] ?? 'Chào mừng bạn đến với Zev v1.0!') ?>" placeholder="Thông báo hiển thị ở trang chủ">
      </div>

      <div class="form-group">
        <label style="display: block; margin-bottom: 8px; font-weight: 500;">Telegram Support / Group Link</label>
        <input type="url" name="config[support_telegram]" class="form-control" value="<?= htmlspecialchars($currentConfig['support_telegram'] ?? 'https://t.me/zev_support') ?>" placeholder="https://t.me/...">
      </div>

      <div class="form-group">
        <label style="display: block; margin-bottom: 8px; font-weight: 500;">Discord Community Link</label>
        <input type="url" name="config[support_discord]" class="form-control" value="<?= htmlspecialchars($currentConfig['support_discord'] ?? '') ?>" placeholder="https://discord.gg/...">
      </div>
    </div>
  </div>

  <div>
    <button type="submit" class="btn btn-primary" style="padding: 12px 28px; font-weight: 600; font-size: 1rem;">
      💾 Lưu Tất Cả Cấu Hình
    </button>
  </div>
</form>

<?php require_once ZEV_ROOT . '/admin/partials/footer.php'; ?>
