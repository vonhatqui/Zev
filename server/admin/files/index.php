<?php
/**
 * ZEV Admin — Quản lý File (Mod, Config, Patch, Dylib)
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

// Xử lý upload file mới
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_FILES['file_upload'])) {
    $title       = sanitizeString($_POST['title'] ?? '');
    $gameId      = !empty($_POST['game_id']) ? (int)$_POST['game_id'] : null;
    $version     = sanitizeString($_POST['version'] ?? '1.0');
    $description = sanitizeString($_POST['description'] ?? '');
    $targetPath  = sanitizeString($_POST['target_path'] ?? 'Documents/');

    $file = $_FILES['file_upload'];
    if ($file['error'] === UPLOAD_ERR_OK && !empty($title)) {
        $origName = basename($file['name']);
        $ext = strtolower(pathinfo($origName, PATHINFO_EXTENSION));
        $allowedExts = ['3105', 'bytes', 'gzip', 'unityfs', 'zip', 'dylib', 'deb', 'json', 'plist', 'txt', 'ipa', 'dat', 'bin', 'config'];

        if (!in_array($ext, $allowedExts)) {
            $errorMsg = "Định dạng file không được hỗ trợ (chấp nhận: " . implode(', ', $allowedExts) . ")";
        } else {
            $uploadDir = ZEV_ROOT . '/uploads/files/';
            if (!is_dir($uploadDir)) {
                @mkdir($uploadDir, 0755, true);
            }

            $storageName = uniqid('zev_', true) . '.' . $ext;
            $fullPath    = $uploadDir . $storageName;

            if (move_uploaded_file($file['tmp_name'], $fullPath)) {
                $fileSize = filesize($fullPath);
                $fileHash = hash_file('sha256', $fullPath);

                $db->execute("
                    INSERT INTO file_records (display_name, original_name, stored_filename, file_path, file_size, checksum_sha256, mime_type, game_id, file_version, target_path, description, status, uploaded_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', NOW(), NOW())
                ", [
                    $title, $origName, $storageName, $storageName, $fileSize, $fileHash, $ext, $gameId, $version, $targetPath, $description
                ]);

                $successMsg = "Tải lên file thành công: " . htmlspecialchars($origName);
            } else {
                $errorMsg = "Không thể lưu file trên máy chủ. Vui lòng kiểm tra quyền thư mục.";
            }
        }
    } else {
        $errorMsg = "Vui lòng chọn file hợp lệ và nhập tiêu đề.";
    }
}

// Xử lý xóa file
if (isset($_GET['delete'])) {
    $deleteId = (int)$_GET['delete'];
    $fileData = $db->fetchOne("SELECT * FROM file_records WHERE id = ?", [$deleteId]);
    if ($fileData) {
        $filePath = ZEV_ROOT . '/uploads/files/' . $fileData['stored_filename'];
        if (file_exists($filePath)) {
            @unlink($filePath);
        }
        $db->execute("DELETE FROM file_records WHERE id = ?", [$deleteId]);
        $successMsg = "Đã xoá file thành công!";
    }
}

// Lấy danh sách games để gán file
$games = $db->fetchAll("SELECT id, display_name FROM games ORDER BY sort_order ASC");

// Lấy danh sách files hiện có
$files = $db->fetchAll("
    SELECT fr.*, g.display_name as game_name 
    FROM file_records fr 
    LEFT JOIN games g ON fr.game_id = g.id 
    ORDER BY fr.id DESC
");

$pageTitle = 'Quản lý File & Cấu hình';
$activePage = 'files';
require_once ZEV_ROOT . '/admin/partials/header.php';
?>

<div class="page-header" style="margin-bottom: 24px; display: flex; justify-content: space-between; align-items: center;">
  <div>
    <h1 style="font-size: 1.5rem; font-weight: 700; color: #fff; margin-bottom: 4px;">Quản lý File & Cấu hình</h1>
    <p style="color: var(--color-text-muted); font-size: 0.9rem;">
      Upload mod, dylib, config game và phân phối tải về bảo mật theo Token.
    </p>
  </div>
  <button onclick="document.getElementById('uploadModal').style.display='flex'" class="btn btn-primary">
    + Upload File Mới
  </button>
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

<!-- Table Files -->
<div class="card" style="padding: 0; overflow: hidden;">
  <div class="table-responsive">
    <table class="table" style="width: 100%; border-collapse: collapse;">
      <thead>
        <tr style="border-bottom: 1px solid var(--color-border); background: rgba(255,255,255,0.02); text-align: left;">
          <th style="padding: 14px 16px;">Tên File / Tiêu đề</th>
          <th style="padding: 14px 16px;">Game</th>
          <th style="padding: 14px 16px;">Phiên bản</th>
          <th style="padding: 14px 16px;">Kích thước</th>
          <th style="padding: 14px 16px;">Yêu cầu VIP</th>
          <th style="padding: 14px 16px;">Lượt tải</th>
          <th style="padding: 14px 16px;">Ngày tạo</th>
          <th style="padding: 14px 16px; text-align: right;">Hành động</th>
        </tr>
      </thead>
      <tbody>
        <?php if (empty($files)): ?>
          <tr>
            <td colspan="8" style="padding: 32px; text-align: center; color: var(--color-text-muted);">
              Chưa có file nào được tải lên.
            </td>
          </tr>
        <?php else: ?>
          <?php foreach ($files as $f): ?>
            <tr style="border-bottom: 1px solid rgba(255,255,255,0.05);">
              <td style="padding: 14px 16px;">
                <div style="font-weight: 600; color: #fff;"><?= htmlspecialchars($f['title']) ?></div>
                <div style="font-size: 0.8rem; color: var(--color-text-muted); font-family: monospace;">
                  <?= htmlspecialchars($f['original_name']) ?>
                </div>
              </td>
              <td style="padding: 14px 16px;">
                <span class="badge" style="background: var(--color-surface3);"><?= htmlspecialchars($f['game_name'] ?? 'Chung') ?></span>
              </td>
              <td style="padding: 14px 16px;">v<?= htmlspecialchars($f['version']) ?></td>
              <td style="padding: 14px 16px; font-family: monospace;">
                <?= formatBytes($f['file_size']) ?>
              </td>
              <td style="padding: 14px 16px;">
                <?php if ($f['vip_only']): ?>
                  <span class="badge" style="background: rgba(245, 158, 11, 0.2); color: #f59e0b;">VIP Key</span>
                <?php else: ?>
                  <span class="badge" style="background: rgba(34, 197, 94, 0.2); color: #22c55e;">Miễn phí</span>
                <?php endif; ?>
              </td>
              <td style="padding: 14px 16px; font-weight: 600;">
                <?= number_format($f['download_count']) ?>
              </td>
              <td style="padding: 14px 16px; font-size: 0.85rem; color: var(--color-text-muted);">
                <?= date('d/m/Y H:i', strtotime($f['created_at'])) ?>
              </td>
              <td style="padding: 14px 16px; text-align: right;">
                <a href="?delete=<?= $f['id'] ?>" onclick="return confirm('Bạn chắc chắn muốn xoá file này?')" class="btn btn-sm" style="background: rgba(239, 68, 68, 0.15); color: #ef4444;">
                  🗑️ Xoá
                </a>
              </td>
            </tr>
          <?php endforeach; ?>
        <?php endif; ?>
      </tbody>
    </table>
  </div>
</div>

<!-- Modal Upload -->
<div id="uploadModal" style="display: none; position: fixed; inset: 0; background: rgba(0,0,0,0.7); z-index: 1000; align-items: center; justify-content: center; backdrop-filter: blur(4px);">
  <div class="card" style="width: 500px; max-width: 90vw; background: var(--color-surface); border: 1px solid var(--color-border); box-shadow: 0 20px 40px rgba(0,0,0,0.5);">
    <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 16px; border-bottom: 1px solid var(--color-border); padding-bottom: 12px;">
      <h3 style="color: #fff; font-size: 1.2rem; font-weight: 600;">Upload File Mới</h3>
      <button onclick="document.getElementById('uploadModal').style.display='none'" style="background: none; border: none; color: var(--color-text-muted); font-size: 1.2rem; cursor: pointer;">✕</button>
    </div>

    <form method="POST" enctype="multipart/form-data" style="display: flex; flex-direction: column; gap: 14px;">
      <div class="form-group">
        <label style="display: block; margin-bottom: 6px; font-weight: 500;">Chọn File (zip, dylib, deb, json, plist...)</label>
        <input type="file" name="file_upload" required class="form-control">
      </div>

      <div class="form-group">
        <label style="display: block; margin-bottom: 6px; font-weight: 500;">Tiêu đề hiển thị</label>
        <input type="text" name="title" required class="form-control" placeholder="ví dụ: Free Fire Mod Menu v1.0">
      </div>

      <div style="display: grid; grid-template-columns: 1fr 1fr; gap: 12px;">
        <div class="form-group">
          <label style="display: block; margin-bottom: 6px; font-weight: 500;">Áp dụng cho Game</label>
          <select name="game_id" class="form-control">
            <option value="">-- Dùng chung --</option>
            <?php foreach ($games as $g): ?>
              <option value="<?= $g['id'] ?>"><?= htmlspecialchars($g['name']) ?></option>
            <?php endforeach; ?>
          </select>
        </div>

        <div class="form-group">
          <label style="display: block; margin-bottom: 6px; font-weight: 500;">Phiên bản</label>
          <input type="text" name="version" class="form-control" value="1.0">
        </div>
      </div>

      <div class="form-group">
        <label style="display: block; margin-bottom: 6px; font-weight: 500;">Mô tả ngắn</label>
        <textarea name="description" class="form-control" rows="2" placeholder="Ghi chú về tính năng của bản cập nhật..."></textarea>
      </div>

      <div class="form-group" style="display: flex; align-items: center; gap: 8px;">
        <input type="checkbox" id="vip_only" name="vip_only" value="1" checked>
        <label for="vip_only" style="cursor: pointer; font-size: 0.9rem;">Chỉ dành cho thiết bị đã kích hoạt Key VIP</label>
      </div>

      <div style="display: flex; justify-content: flex-end; gap: 10px; margin-top: 10px;">
        <button type="button" onclick="document.getElementById('uploadModal').style.display='none'" class="btn" style="background: var(--color-surface2); color: #fff;">Hủy</button>
        <button type="submit" class="btn btn-primary">Bắt đầu Upload</button>
      </div>
    </form>
  </div>
</div>

<?php require_once ZEV_ROOT . '/admin/partials/footer.php'; ?>
