<?php
/**
 * ZEV Admin — Quản lý Key: Danh sách
 */

define('ZEV_ROOT', dirname(__DIR__, 2));
require_once ZEV_ROOT . '/src/helpers.php';
require_once ZEV_ROOT . '/src/Config/Database.php';
require_once ZEV_ROOT . '/src/Auth/AdminAuth.php';

use Zev\Auth\AdminAuth;
use Zev\Config\Database;

AdminAuth::requireLogin();

$db = Database::getInstance();

// Filters
$search     = sanitizeString($_GET['q'] ?? '', 100);
$statusFilter = sanitizeString($_GET['status'] ?? '', 20);
$page       = max(1, (int)($_GET['page'] ?? 1));
$perPage    = 20;
$offset     = ($page - 1) * $perPage;

$where  = ['1=1'];
$params = [];

if ($search) {
    $where[]  = 'ak.key_code LIKE ?';
    $params[] = "%{$search}%";
}

if (in_array($statusFilter, ['active','expired','revoked','suspended'])) {
    $where[]  = 'ak.status = ?';
    $params[] = $statusFilter;
}

$whereStr = implode(' AND ', $where);

$total = $db->fetchOne(
    "SELECT COUNT(*) as cnt FROM activation_keys ak WHERE {$whereStr}",
    $params
)['cnt'];

$keys = $db->fetchAll(
    "SELECT ak.*, 
            COUNT(db.id) as device_count
     FROM activation_keys ak
     LEFT JOIN device_bindings db ON db.key_id = ak.id AND db.is_active = 1
     WHERE {$whereStr}
     GROUP BY ak.id
     ORDER BY ak.created_at DESC
     LIMIT {$perPage} OFFSET {$offset}",
    $params
);

$totalPages = max(1, ceil($total / $perPage));

$pageTitle  = 'Quản lý Key';
$activePage = 'keys';
require_once ZEV_ROOT . '/admin/partials/header.php';
?>

<div style="display:flex; align-items:center; justify-content:space-between; margin-bottom:20px;">
  <h2 style="font-size:1.15rem; font-weight:700;">🔑 Quản lý Key</h2>
  <a href="/admin/keys/create.php" class="btn btn-primary">+ Tạo Key mới</a>
</div>

<div class="card">
  <div class="card-header">
    <div class="table-toolbar" style="margin:0; width:100%;">
      <form method="GET" style="display:flex; gap:10px; flex:1; flex-wrap:wrap;">
        <div class="search-box">
          <span class="search-icon">🔍</span>
          <input
            type="text"
            name="q"
            class="form-control"
            placeholder="Tìm key..."
            value="<?= htmlspecialchars($search) ?>"
            id="searchInput"
          >
        </div>
        <select name="status" class="form-control" style="width:160px;" onchange="this.form.submit()">
          <option value="">Tất cả trạng thái</option>
          <option value="active"    <?= $statusFilter==='active'    ? 'selected' : '' ?>>✅ Hoạt động</option>
          <option value="expired"   <?= $statusFilter==='expired'   ? 'selected' : '' ?>>⏰ Hết hạn</option>
          <option value="revoked"   <?= $statusFilter==='revoked'   ? 'selected' : '' ?>>🚫 Thu hồi</option>
          <option value="suspended" <?= $statusFilter==='suspended' ? 'selected' : '' ?>>⏸️ Tạm khóa</option>
        </select>
        <button type="submit" class="btn btn-secondary">Lọc</button>
        <?php if ($search || $statusFilter): ?>
        <a href="/admin/keys/" class="btn btn-secondary">✕ Xóa lọc</a>
        <?php endif; ?>
      </form>
      <span style="font-size:0.82rem; color:var(--color-text-muted);">Tổng: <strong><?= number_format($total) ?></strong></span>
    </div>
  </div>

  <div class="table-wrap">
    <table class="data-table">
      <thead>
        <tr>
          <th>Key Code</th>
          <th>Trạng thái</th>
          <th>Hết hạn</th>
          <th>Thiết bị</th>
          <th>Lần kích hoạt cuối</th>
          <th>Tạo lúc</th>
          <th>Hành động</th>
        </tr>
      </thead>
      <tbody>
        <?php if (empty($keys)): ?>
        <tr>
          <td colspan="7">
            <div class="empty-state">
              <div class="empty-state-icon">🔍</div>
              <h3>Không tìm thấy key nào</h3>
              <p><?= $search ? 'Thử từ khóa khác' : 'Chưa có key nào được tạo' ?></p>
            </div>
          </td>
        </tr>
        <?php else: ?>
        <?php foreach ($keys as $key):
          $isExpired = $key['expires_at'] && strtotime($key['expires_at']) <= time();
          $displayStatus = ($key['status'] === 'active' && $isExpired) ? 'expired' : $key['status'];
        ?>
        <tr>
          <td>
            <span class="key-display" onclick="copyText('<?= htmlspecialchars($key['key_code']) ?>')" title="Click để sao chép">
              <?= htmlspecialchars($key['key_code']) ?>
            </span>
          </td>
          <td>
            <span class="badge badge-<?= $displayStatus ?>">
              <?php
                $statusLabels = [
                  'active'    => '✅ Hoạt động',
                  'expired'   => '⏰ Hết hạn',
                  'revoked'   => '🚫 Thu hồi',
                  'suspended' => '⏸️ Tạm khóa',
                ];
                echo $statusLabels[$displayStatus] ?? $displayStatus;
              ?>
            </span>
          </td>
          <td style="font-size:0.85rem; <?= $isExpired ? 'color:var(--color-danger)' : '' ?>">
            <?= $key['expires_at'] ? date('d/m/Y H:i', strtotime($key['expires_at'])) : '♾️ Vĩnh viễn' ?>
          </td>
          <td>
            <span class="badge badge-primary"><?= (int)$key['device_count'] ?> thiết bị</span>
          </td>
          <td style="font-size:0.82rem; color:var(--color-text-muted);">
            <?= $key['last_activated_at'] ? date('d/m/Y H:i', strtotime($key['last_activated_at'])) : '—' ?>
          </td>
          <td style="font-size:0.82rem; color:var(--color-text-dim);">
            <?= date('d/m/Y', strtotime($key['created_at'])) ?>
          </td>
          <td>
            <div style="display:flex; gap:6px;">
              <a href="/admin/keys/detail.php?id=<?= $key['id'] ?>" class="btn btn-secondary btn-sm" title="Chi tiết">👁️</a>
              <?php if ($displayStatus === 'active'): ?>
              <button onclick="revokeKey(<?= $key['id'] ?>, '<?= htmlspecialchars($key['key_code']) ?>')" class="btn btn-danger btn-sm" title="Thu hồi">🚫</button>
              <?php elseif ($displayStatus === 'revoked' || $displayStatus === 'suspended'): ?>
              <button onclick="restoreKey(<?= $key['id'] ?>)" class="btn btn-success btn-sm" title="Mở khóa">✅</button>
              <?php endif; ?>
            </div>
          </td>
        </tr>
        <?php endforeach; ?>
        <?php endif; ?>
      </tbody>
    </table>
  </div>

  <!-- Pagination -->
  <?php if ($totalPages > 1): ?>
  <div style="padding:0 16px 16px;">
    <div class="pagination">
      <?php if ($page > 1): ?>
      <a href="?page=<?= $page-1 ?>&q=<?= urlencode($search) ?>&status=<?= urlencode($statusFilter) ?>" class="page-btn">‹</a>
      <?php endif; ?>

      <?php for ($i = max(1, $page-2); $i <= min($totalPages, $page+2); $i++): ?>
      <a href="?page=<?= $i ?>&q=<?= urlencode($search) ?>&status=<?= urlencode($statusFilter) ?>"
         class="page-btn <?= $i === $page ? 'active' : '' ?>"><?= $i ?></a>
      <?php endfor; ?>

      <?php if ($page < $totalPages): ?>
      <a href="?page=<?= $page+1 ?>&q=<?= urlencode($search) ?>&status=<?= urlencode($statusFilter) ?>" class="page-btn">›</a>
      <?php endif; ?>
    </div>
  </div>
  <?php endif; ?>
</div>

<!-- Confirm Modals -->
<div class="modal-overlay" id="revokeModal">
  <div class="modal">
    <div class="modal-header">
      <h3 class="modal-title">🚫 Thu hồi Key</h3>
      <button class="modal-close" onclick="closeModal('revokeModal')">✕</button>
    </div>
    <div class="modal-body">
      <p>Bạn có chắc muốn <strong>thu hồi</strong> key <code id="revokeKeyCode"></code>?</p>
      <p style="margin-top:8px; font-size:0.85rem; color:var(--color-text-muted);">Người dùng sẽ không thể đăng nhập bằng key này nữa.</p>
      <div class="form-group" style="margin-top:16px; margin-bottom:0;">
        <label class="form-label">Lý do thu hồi (tùy chọn)</label>
        <input type="text" class="form-control" id="revokeReason" placeholder="Vi phạm điều khoản...">
      </div>
    </div>
    <div class="modal-footer">
      <button class="btn btn-secondary" onclick="closeModal('revokeModal')">Hủy</button>
      <button class="btn btn-danger" onclick="confirmRevoke()">Thu hồi</button>
    </div>
  </div>
</div>

<?php
$extraScripts = '<script>
let revokeKeyId = null;

function revokeKey(id, code) {
  revokeKeyId = id;
  document.getElementById("revokeKeyCode").textContent = code;
  document.getElementById("revokeReason").value = "";
  openModal("revokeModal");
}

async function confirmRevoke() {
  const reason = document.getElementById("revokeReason").value;
  const resp = await fetch("/admin/keys/action.php", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ action: "revoke", id: revokeKeyId, reason })
  });
  const data = await resp.json();
  if (data.success) {
    showToast("✅ Đã thu hồi key thành công", "success");
    setTimeout(() => location.reload(), 1000);
  } else {
    showToast("❌ " + data.message, "error");
  }
  closeModal("revokeModal");
}

async function restoreKey(id) {
  if (!confirm("Mở khóa key này?")) return;
  const resp = await fetch("/admin/keys/action.php", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ action: "restore", id })
  });
  const data = await resp.json();
  if (data.success) {
    showToast("✅ Đã mở khóa key", "success");
    setTimeout(() => location.reload(), 1000);
  } else {
    showToast("❌ " + data.message, "error");
  }
}
</script>';

require_once ZEV_ROOT . '/admin/partials/footer.php';
?>
