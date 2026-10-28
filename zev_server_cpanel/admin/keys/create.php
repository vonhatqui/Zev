<?php
/**
 * ZEV Admin — Tạo Key mới
 */

define('ZEV_ROOT', dirname(__DIR__, 2));
require_once ZEV_ROOT . '/src/helpers.php';
require_once ZEV_ROOT . '/src/Config/Database.php';
require_once ZEV_ROOT . '/src/Auth/AdminAuth.php';

use Zev\Auth\AdminAuth;
use Zev\Config\Database;

AdminAuth::requireLogin();

$db    = Database::getInstance();
$admin = AdminAuth::currentAdmin();

$message = '';
$msgType = '';
$generatedKeys = [];

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $quantity    = max(1, min(100, (int)($_POST['quantity'] ?? 1)));
    $duration    = (int)($_POST['duration_days'] ?? 30);
    $isLifetime  = isset($_POST['lifetime']);
    $note        = sanitizeString($_POST['note'] ?? '', 255);
    $prefix      = 'ZEV';

    if ($duration <= 0 && !$isLifetime) {
        $message = 'Thời hạn không hợp lệ.';
        $msgType = 'danger';
    } else {
        $created = 0;
        for ($i = 0; $i < $quantity; $i++) {
            $keyCode = generateKeyCode($prefix);
            $expiresAt = $isLifetime ? null : date('Y-m-d H:i:s', strtotime("+{$duration} days"));

            try {
                $db->insert(
                    "INSERT INTO activation_keys (key_code, duration_days, expires_at, status, note, created_by) VALUES (?, ?, ?, 'active', ?, ?)",
                    [$keyCode, $isLifetime ? 0 : $duration, $expiresAt, $note, $admin['id']]
                );

                // Log activity
                $db->insert(
                    "INSERT INTO activity_logs (actor_type, actor_id, actor_label, action, target_type, target_label, ip_address) VALUES ('admin', ?, ?, 'key.create', 'key', ?, ?)",
                    [$admin['id'], $admin['username'], $keyCode, getClientIp()]
                );

                $generatedKeys[] = $keyCode;
                $created++;
            } catch (\Throwable $e) {
                // Key trùng — thử lại (rất hiếm)
                $i--;
                if ($i < -10) break; // Safety limit
            }
        }

        $message = "Đã tạo thành công {$created} key.";
        $msgType = 'success';
    }
}

function generateKeyCode(string $prefix): string
{
    $chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    $parts = [];
    for ($i = 0; $i < 3; $i++) {
        $part = '';
        for ($j = 0; $j < 4; $j++) {
            $part .= $chars[random_int(0, strlen($chars) - 1)];
        }
        $parts[] = $part;
    }
    return $prefix . '-' . implode('-', $parts);
}

$pageTitle  = 'Tạo Key mới';
$activePage = 'keys';
require_once ZEV_ROOT . '/admin/partials/header.php';
?>

<div style="max-width:640px;">

  <div style="display:flex; align-items:center; gap:12px; margin-bottom:24px;">
    <a href="/admin/keys/" class="btn btn-secondary btn-sm">← Quay lại</a>
    <h2 style="font-size:1.15rem; font-weight:700;">🔑 Tạo Key mới</h2>
  </div>

  <?php if ($message): ?>
  <div class="alert alert-<?= $msgType ?>"><?= htmlspecialchars($message) ?></div>
  <?php endif; ?>

  <?php if (!empty($generatedKeys)): ?>
  <div class="card" style="margin-bottom:24px;">
    <div class="card-header">
      <span class="card-title">✅ Key đã tạo (<?= count($generatedKeys) ?>)</span>
      <button onclick="copyAllKeys()" class="btn btn-secondary btn-sm">📋 Sao chép tất cả</button>
    </div>
    <div class="card-body" id="keyListDisplay" style="display:flex; flex-direction:column; gap:10px;">
      <?php foreach ($generatedKeys as $k): ?>
      <div style="display:flex; align-items:center; justify-content:space-between; background:var(--color-surface-2); padding:10px 14px; border-radius:var(--radius-md); border:1px solid var(--color-border);">
        <span class="key-display" onclick="copyText('<?= htmlspecialchars($k) ?>')"><?= htmlspecialchars($k) ?></span>
        <button class="copy-btn" onclick="copyText('<?= htmlspecialchars($k) ?>')" title="Sao chép">📋</button>
      </div>
      <?php endforeach; ?>
    </div>
  </div>
  <?php endif; ?>

  <div class="card">
    <div class="card-header">
      <span class="card-title">Thông tin Key</span>
    </div>
    <div class="card-body">
      <form method="POST">
        <div class="form-group">
          <label class="form-label">Số lượng key</label>
          <input type="number" name="quantity" class="form-control" value="1" min="1" max="100" required>
          <div class="form-hint">Tối đa 100 key mỗi lần tạo</div>
        </div>

        <div class="form-group">
          <label class="form-label">Thời hạn</label>
          <div style="display:flex; gap:10px; align-items:center; flex-wrap:wrap;">
            <select name="duration_days" class="form-control" style="width:200px;" id="durationSelect">
              <option value="7">7 ngày</option>
              <option value="15">15 ngày</option>
              <option value="30" selected>30 ngày</option>
              <option value="60">60 ngày</option>
              <option value="90">90 ngày</option>
              <option value="180">6 tháng</option>
              <option value="365">1 năm</option>
              <option value="custom">Tùy chỉnh...</option>
            </select>
            <label style="display:flex; align-items:center; gap:8px; font-size:0.875rem; cursor:pointer;">
              <input type="checkbox" name="lifetime" id="lifetimeCheck" onchange="toggleLifetime(this)">
              <span>♾️ Vĩnh viễn</span>
            </label>
          </div>
          <div id="customDuration" style="display:none; margin-top:10px;">
            <input type="number" name="custom_days" class="form-control" placeholder="Số ngày (ví dụ: 45)" min="1" style="width:200px;">
          </div>
        </div>

        <div class="form-group">
          <label class="form-label">Ghi chú (tùy chọn)</label>
          <input type="text" name="note" class="form-control" placeholder="Ghi chú cho batch key này...">
        </div>

        <div style="display:flex; gap:10px; margin-top:8px;">
          <button type="submit" class="btn btn-primary">🔑 Tạo Key</button>
          <a href="/admin/keys/" class="btn btn-secondary">Hủy</a>
        </div>
      </form>
    </div>
  </div>
</div>

<?php
$extraScripts = '<script>
function toggleLifetime(cb) {
  document.getElementById("durationSelect").disabled = cb.checked;
}

document.getElementById("durationSelect").addEventListener("change", function() {
  document.getElementById("customDuration").style.display = this.value === "custom" ? "block" : "none";
});

function copyAllKeys() {
  const keys = [...document.querySelectorAll(".key-display")].map(el => el.textContent).join("\n");
  copyText(keys);
  showToast("Đã sao chép tất cả key", "success");
}
</script>';

require_once ZEV_ROOT . '/admin/partials/footer.php';
?>
