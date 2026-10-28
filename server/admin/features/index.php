<?php
/**
 * ZEV Admin — Quản lý Danh mục, Chức năng & File ứng dụng Zev
 * Cho phép tùy chỉnh tên, trạng thái và upload file .3105, cache file cho từng chức năng
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
$errorMsg   = '';

// 1. Lấy danh sách Game
$games = $db->fetchAll("SELECT * FROM games ORDER BY sort_order ASC, id ASC");
$selectedGameId = isset($_GET['game_id']) ? (int)$_GET['game_id'] : ($games[0]['id'] ?? 1);

// 2. Xử lý Thêm / Sửa Danh mục
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'save_category') {
    $catId       = !empty($_POST['cat_id']) ? (int)$_POST['cat_id'] : 0;
    $gameId      = (int)($_POST['game_id'] ?? $selectedGameId);
    $displayName = sanitizeString($_POST['display_name'] ?? '', 128);
    $slug        = sanitizeString($_POST['slug'] ?? '', 64);
    $logoUrl     = sanitizeString($_POST['logo_url'] ?? '', 512);
    $description = sanitizeString($_POST['description'] ?? '', 255);
    $sortOrder   = (int)($_POST['sort_order'] ?? 0);

    if (empty($displayName)) {
        $errorMsg = 'Tên danh mục không được để trống.';
    } else {
        if (empty($slug)) {
            $slug = strtolower(trim(preg_replace('/[^A-Za-z0-9-]+/', '-', $displayName)));
        }

        if ($catId > 0) {
            $db->execute("
                UPDATE feature_categories 
                SET display_name = ?, slug = ?, logo_url = ?, description = ?, sort_order = ?, updated_at = NOW()
                WHERE id = ?
            ", [$displayName, $slug, $logoUrl, $description, $sortOrder, $catId]);
            $successMsg = "Đã cập nhật danh mục: {$displayName}";
        } else {
            $db->execute("
                INSERT INTO feature_categories (game_id, slug, display_name, logo_url, description, sort_order, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())
            ", [$gameId, $slug, $displayName, $logoUrl, $description, $sortOrder]);
            $successMsg = "Đã thêm danh mục mới: {$displayName}";
        }
    }
}

// 3. Xử lý Thêm / Sửa Chức năng & Nạp File
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'save_feature') {
    $featureId   = !empty($_POST['feature_id']) ? (int)$_POST['feature_id'] : 0;
    $categoryId  = (int)($_POST['category_id'] ?? 0);
    $displayName = sanitizeString($_POST['display_name'] ?? '', 128);
    $slug        = sanitizeString($_POST['slug'] ?? '', 64);
    $description = sanitizeString($_POST['description'] ?? '', 255);
    $status      = sanitizeString($_POST['status'] ?? 'unsupported', 32);
    $previewUrl  = sanitizeString($_POST['preview_url'] ?? '', 512);
    $targetPath  = sanitizeString($_POST['target_path'] ?? 'Documents/', 255);
    $sortOrder   = (int)($_POST['sort_order'] ?? 0);

    if (empty($displayName) || $categoryId <= 0) {
        $errorMsg = 'Vui lòng chọn danh mục và nhập tên chức năng.';
    } else {
        if (empty($slug)) {
            $slug = strtolower(trim(preg_replace('/[^A-Za-z0-9-]+/', '-', $displayName)));
        }

        $selectedFileId = isset($_POST['file_id']) ? (int)$_POST['file_id'] : -1;
        $uploadedFileId = null;

        // Xử lý upload file mới nếu có
        if (isset($_FILES['feature_file']) && $_FILES['feature_file']['error'] !== UPLOAD_ERR_NO_FILE) {
            if ($_FILES['feature_file']['error'] !== UPLOAD_ERR_OK) {
                $uploadErrors = [
                    UPLOAD_ERR_INI_SIZE   => 'Dung lượng file vượt quá giới hạn của PHP (upload_max_filesize). Vui lòng tăng giới hạn trên cPanel hoặc upload qua trang Quản lý File.',
                    UPLOAD_ERR_FORM_SIZE  => 'Dung lượng file vượt quá giới hạn form.',
                    UPLOAD_ERR_PARTIAL    => 'File chỉ mới được tải lên một phần.',
                    UPLOAD_ERR_NO_TMP_DIR => 'Thiếu thư mục tạm thời trên máy chủ.',
                    UPLOAD_ERR_CANT_WRITE => 'Không thể ghi file vào ổ đĩa máy chủ.',
                    UPLOAD_ERR_EXTENSION  => 'Quá trình tải lên bị chặn bởi tiện ích mở rộng PHP.',
                ];
                $errorMsg = $uploadErrors[$_FILES['feature_file']['error']] ?? 'Lỗi tải lên file (Mã lỗi: ' . $_FILES['feature_file']['error'] . ')';
            } else {
                $fileObj   = $_FILES['feature_file'];
                $origName  = basename($fileObj['name']);
                $fileExt   = strtolower(pathinfo($origName, PATHINFO_EXTENSION));
                
                // Cho phép các đuôi file .3105, bytes, gzip, unityfs, json, zip, config, dat
                $allowedExts = ['3105', 'bytes', 'gzip', 'unityfs', 'json', 'plist', 'zip', 'dat', 'bin', 'config', 'txt', 'dylib', 'deb'];

                if (!in_array($fileExt, $allowedExts)) {
                    $errorMsg = "Định dạng file không hợp lệ. Chỉ chấp nhận: " . implode(', ', $allowedExts);
                } else {
                    $uploadDir = ZEV_ROOT . '/uploads/files/';
                    if (!is_dir($uploadDir)) {
                        @mkdir($uploadDir, 0755, true);
                    }

                    $storageName = 'zev_' . time() . '_' . bin2hex(random_bytes(6)) . '.' . $fileExt;
                    $targetFile  = $uploadDir . $storageName;

                    if (move_uploaded_file($fileObj['tmp_name'], $targetFile)) {
                        $fileSize = filesize($targetFile);
                        $fileHash = hash_file('sha256', $targetFile);

                        $uploadedFileId = $db->insert("
                            INSERT INTO file_records (original_name, display_name, stored_filename, file_path, file_size, mime_type, checksum_sha256, game_id, target_path, status, uploaded_at, updated_at)
                            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', NOW(), NOW())
                        ", [
                            $origName, $displayName, $storageName, $storageName, $fileSize, $fileExt, $fileHash, $selectedGameId, $targetPath
                        ]);
                        
                        $status = 'ready';
                    } else {
                        $errorMsg = "Không thể lưu file trên máy chủ. Vui lòng kiểm tra quyền thư mục uploads/.";
                    }
                }
            }
        }

        if (empty($errorMsg)) {
            // Xác định file_id cuối cùng
            if ($uploadedFileId) {
                $finalFileId = $uploadedFileId;
            } elseif ($selectedFileId > 0) {
                $finalFileId = $selectedFileId;
                if ($status === 'unsupported' || $status === 'no_file') {
                    $status = 'ready';
                }
            } elseif ($selectedFileId === 0) {
                $finalFileId = null; // Gỡ file
                if ($status === 'ready') {
                    $status = 'unsupported';
                }
            } else {
                // Giữ nguyên file cũ nếu không thay đổi
                $existing = $featureId > 0 ? $db->fetchOne("SELECT file_id FROM features WHERE id = ?", [$featureId]) : null;
                $finalFileId = $existing['file_id'] ?? null;
            }

            if ($featureId > 0) {
                $db->execute("
                    UPDATE features 
                    SET category_id = ?, display_name = ?, slug = ?, description = ?, status = ?, file_id = ?, preview_url = ?, sort_order = ?, updated_at = NOW()
                    WHERE id = ?
                ", [$categoryId, $displayName, $slug, $description, $status, $finalFileId, $previewUrl, $sortOrder, $featureId]);
                $successMsg = "Đã cập nhật tính năng: {$displayName}";
            } else {
                $db->execute("
                    INSERT INTO features (category_id, slug, display_name, description, status, file_id, preview_url, sort_order, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())
                ", [$categoryId, $slug, $displayName, $description, $status, $finalFileId, $previewUrl, $sortOrder]);
                $successMsg = "Đã thêm tính năng mới: {$displayName}";
            }
        }
    }
}

// 4. Xóa Danh mục hoặc Chức năng
if (isset($_GET['delete_cat'])) {
    $delId = (int)$_GET['delete_cat'];
    $db->execute("DELETE FROM feature_categories WHERE id = ?", [$delId]);
    $successMsg = "Đã xóa danh mục thành công.";
}

if (isset($_GET['delete_feature'])) {
    $delId = (int)$_GET['delete_feature'];
    $db->execute("DELETE FROM features WHERE id = ?", [$delId]);
    $successMsg = "Đã xóa chức năng thành công.";
}

// 5. Lấy danh sách Categories & Features cho Game đang chọn
$categories = $db->fetchAll("
    SELECT * FROM feature_categories 
    WHERE game_id = ? 
    ORDER BY sort_order ASC, id ASC
", [$selectedGameId]);

$featuresByCat = [];
if (!empty($categories)) {
    $catIds = array_column($categories, 'id');
    $placeholders = implode(',', array_fill(0, count($catIds), '?'));
    
    $features = $db->fetchAll("
        SELECT f.*, fr.original_name as file_name, fr.file_size, fr.target_path, fr.checksum_sha256
        FROM features f
        LEFT JOIN file_records fr ON fr.id = f.file_id
        WHERE f.category_id IN ({$placeholders})
        ORDER BY f.sort_order ASC, f.id ASC
    ", $catIds);

    foreach ($features as $f) {
        $featuresByCat[$f['category_id']][] = $f;
    }
}

// Lấy danh sách toàn bộ file đã upload để cho phép gán trực tiếp vào chức năng
$allFiles = $db->fetchAll("
    SELECT id, display_name, original_name, file_size 
    FROM file_records 
    WHERE status = 'active' 
    ORDER BY id DESC
");

$pageTitle  = 'Quản lý Chức năng & File';
$activePage = 'features';
require_once ZEV_ROOT . '/admin/partials/header.php';
?>

<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px; flex-wrap:wrap; gap:12px;">
  <div>
    <h2 style="font-size:1.3rem; font-weight:700; color:#fff; margin-bottom:4px;">🎯 Quản lý Danh mục & File Chức năng</h2>
    <p style="color:var(--color-text-muted); font-size:0.88rem;">
      Tùy chỉnh các danh mục (Menu, Aim, Modskin, Antiban) và nạp file (.3105, cache, config) tương ứng.
    </p>
  </div>
  <div style="display:flex; gap:10px;">
    <button onclick="openCategoryModal()" class="btn btn-secondary">+ Thêm Danh Mục</button>
    <button onclick="openFeatureModal()" class="btn btn-primary">+ Thêm Chức Năng</button>
  </div>
</div>

<?php if ($successMsg): ?>
  <div class="alert alert-success" style="margin-bottom:16px;">✓ <?= htmlspecialchars($successMsg) ?></div>
<?php endif; ?>
<?php if ($errorMsg): ?>
  <div class="alert alert-danger" style="margin-bottom:16px;">✕ <?= htmlspecialchars($errorMsg) ?></div>
<?php endif; ?>

<!-- Tabs chọn Game -->
<div style="display:flex; gap:8px; margin-bottom:20px; border-bottom:1px solid var(--color-border); padding-bottom:8px;">
  <?php foreach ($games as $g): ?>
  <a href="?game_id=<?= $g['id'] ?>" class="btn <?= $selectedGameId == $g['id'] ? 'btn-primary' : 'btn-secondary' ?>" style="display:flex; align-items:center; gap:8px;">
    <span>🎮</span>
    <strong><?= htmlspecialchars($g['display_name']) ?></strong>
    <span style="font-size:0.75rem; opacity:0.8;">(<?= htmlspecialchars($g['bundle_id']) ?>)</span>
  </a>
  <?php endforeach; ?>
</div>

<!-- Danh sách Categories & Features -->
<div style="display:flex; flex-direction:column; gap:20px;">
  <?php if (empty($categories)): ?>
    <div class="card" style="padding:40px; text-align:center; color:var(--color-text-muted);">
      Chưa có danh mục nào cho game này. Bấm <strong>+ Thêm Danh Mục</strong> để tạo mới.
    </div>
  <?php else: ?>
    <?php foreach ($categories as $cat): ?>
      <?php $cFeatures = $featuresByCat[$cat['id']] ?? []; ?>
      <div class="card" style="border:1px solid rgba(108, 99, 255, 0.25);">
        <div class="card-header" style="display:flex; justify-content:space-between; align-items:center; background:rgba(255,255,255,0.02);">
          <div style="display:flex; align-items:center; gap:12px;">
            <?php if (!empty($cat['logo_url'])): ?>
              <img src="<?= htmlspecialchars($cat['logo_url']) ?>" style="width:34px; height:34px; border-radius:8px; object-fit:contain; background:#1c1d26; padding:3px;" onerror="this.style.display='none'">
            <?php else: ?>
              <span style="font-size:1.4rem;">📁</span>
            <?php endif; ?>
            <div>
              <span style="font-size:1.05rem; font-weight:700; color:#fff;"><?= htmlspecialchars($cat['display_name']) ?></span>
              <span style="font-size:0.8rem; color:var(--color-text-muted); margin-left:8px;">slug: <?= htmlspecialchars($cat['slug']) ?></span>
              <?php if (!empty($cat['description'])): ?>
                <div style="font-size:0.8rem; color:var(--color-text-dim);"><?= htmlspecialchars($cat['description']) ?></div>
              <?php endif; ?>
            </div>
          </div>
          <div style="display:flex; gap:8px;">
            <button onclick='editCategory(<?= json_encode($cat) ?>)' class="btn btn-secondary btn-sm">Sửa</button>
            <a href="?game_id=<?= $selectedGameId ?>&delete_cat=<?= $cat['id'] ?>" class="btn btn-danger btn-sm" onclick="return confirm('Bạn có chắc muốn xóa danh mục này cùng toàn bộ chức năng?')">Xóa</a>
          </div>
        </div>

        <div class="table-wrap">
          <table class="data-table">
            <thead>
              <tr>
                <th style="width:50px;">Thứ tự</th>
                <th>Tên Chức Năng</th>
                <th>Trạng Thái Trên App</th>
                <th>File Nạp & Đích Đến</th>
                <th>Dung Lượng</th>
                <th style="text-align:right;">Thao Tác</th>
              </tr>
            </thead>
            <tbody>
              <?php if (empty($cFeatures)): ?>
                <tr>
                  <td colspan="6" style="text-align:center; color:var(--color-text-muted); padding:20px;">
                    Chưa có chức năng nào trong danh mục này. Bấm <strong>+ Thêm Chức Năng</strong>.
                  </td>
                </tr>
              <?php else: ?>
                <?php foreach ($cFeatures as $f): ?>
                  <tr>
                    <td><?= $f['sort_order'] ?></td>
                    <td>
                      <div style="font-weight:600; color:#fff;"><?= htmlspecialchars($f['display_name']) ?></div>
                      <div style="font-size:0.75rem; color:var(--color-text-muted);"><?= htmlspecialchars($f['slug']) ?></div>
                      <?php if (!empty($f['preview_url'])): ?>
                        <a href="<?= htmlspecialchars($f['preview_url']) ?>" target="_blank" style="font-size:0.75rem; color:var(--color-primary);">🖼️ Xem ảnh preview</a>
                      <?php endif; ?>
                    </td>
                    <td>
                      <?php if ($f['status'] === 'ready' && !empty($f['file_id'])): ?>
                        <span class="badge badge-success">🟢 Sẵn sàng (Ready)</span>
                      <?php elseif ($f['status'] === 'unsupported' || empty($f['file_id'])): ?>
                        <span class="badge badge-danger">🔴 Chưa Hỗ Trợ (App báo Chưa Hỗ Trợ)</span>
                      <?php else: ?>
                        <span class="badge badge-warning">🟡 <?= htmlspecialchars($f['status']) ?></span>
                      <?php endif; ?>
                    </td>
                    <td>
                      <?php if (!empty($f['file_name'])): ?>
                        <div style="font-family:monospace; font-size:0.85rem; color:#a78bfa;">📦 <?= htmlspecialchars($f['file_name']) ?></div>
                        <div style="font-size:0.75rem; color:var(--color-text-muted);">
                          Đích: <code><?= htmlspecialchars($f['target_path'] ?? 'Documents/') ?></code>
                        </div>
                      <?php else: ?>
                        <span style="color:var(--color-text-dim); font-size:0.85rem;">(Chưa gắn file)</span>
                      <?php endif; ?>
                    </td>
                    <td>
                      <?= !empty($f['file_size']) ? number_format($f['file_size'] / 1024, 1) . ' KB' : '—' ?>
                    </td>
                    <td style="text-align:right;">
                      <button onclick='editFeature(<?= json_encode($f) ?>)' class="btn btn-secondary btn-sm">Sửa / Nạp File</button>
                      <a href="?game_id=<?= $selectedGameId ?>&delete_feature=<?= $f['id'] ?>" class="btn btn-danger btn-sm" onclick="return confirm('Xác nhận xóa chức năng này?')">Xóa</a>
                    </td>
                  </tr>
                <?php endforeach; ?>
              <?php endif; ?>
            </tbody>
          </table>
        </div>
      </div>
    <?php endforeach; ?>
  <?php endif; ?>
</div>

<!-- Modal Thêm/Sửa Danh Mục -->
<div id="catModal" class="modal" style="display:none; position:fixed; inset:0; background:rgba(0,0,0,0.7); z-index:999; align-items:center; justify-content:center;">
  <div class="card" style="width:100%; max-width:480px; margin:20px;">
    <div class="card-header" style="display:flex; justify-content:space-between; align-items:center;">
      <h3 id="catModalTitle" style="color:#fff; font-size:1.1rem; margin:0;">Thêm Danh Mục Mới</h3>
      <button onclick="closeCategoryModal()" style="background:none; border:none; color:#fff; font-size:1.2rem; cursor:pointer;">✕</button>
    </div>
    <form method="POST" action="" style="padding:16px; display:flex; flex-direction:column; gap:14px;">
      <input type="hidden" name="action" value="save_category">
      <input type="hidden" name="cat_id" id="cat_id" value="0">
      <input type="hidden" name="game_id" value="<?= $selectedGameId ?>">

      <div class="form-group">
        <label class="form-label">Tên danh mục (Ví dụ: Menu Project, Aim Cache, Modskin FFTH, Setup Antiban)</label>
        <input type="text" name="display_name" id="cat_display_name" class="form-control" required placeholder="Tên hiển thị">
      </div>

      <div class="form-group">
        <label class="form-label">Slug (để trống tự tạo theo tên)</label>
        <input type="text" name="slug" id="cat_slug" class="form-control" placeholder="menu-project">
      </div>

      <div class="form-group">
        <label class="form-label">URL Logo / Icon (Link ảnh catbox hoặc cdn)</label>
        <input type="url" name="logo_url" id="cat_logo_url" class="form-control" placeholder="https://files.catbox.moe/...">
      </div>

      <div class="form-group">
        <label class="form-label">Mô tả ngắn</label>
        <input type="text" name="description" id="cat_description" class="form-control" placeholder="Mô tả danh mục">
      </div>

      <div class="form-group">
        <label class="form-label">Thứ tự hiển thị (Sort order)</label>
        <input type="number" name="sort_order" id="cat_sort_order" class="form-control" value="1">
      </div>

      <div style="display:flex; justify-content:flex-end; gap:8px; margin-top:8px;">
        <button type="button" onclick="closeCategoryModal()" class="btn btn-secondary">Hủy</button>
        <button type="submit" class="btn btn-primary">Lưu Danh Mục</button>
      </div>
    </form>
  </div>
</div>

<!-- Modal Thêm/Sửa Chức Năng & Nạp File -->
<div id="featModal" class="modal" style="display:none; position:fixed; inset:0; background:rgba(0,0,0,0.7); z-index:999; align-items:center; justify-content:center; overflow-y:auto;">
  <div class="card" style="width:100%; max-width:540px; margin:40px auto;">
    <div class="card-header" style="display:flex; justify-content:space-between; align-items:center;">
      <h3 id="featModalTitle" style="color:#fff; font-size:1.1rem; margin:0;">Chức Năng & File</h3>
      <button onclick="closeFeatureModal()" style="background:none; border:none; color:#fff; font-size:1.2rem; cursor:pointer;">✕</button>
    </div>
    <form method="POST" action="" enctype="multipart/form-data" style="padding:16px; display:flex; flex-direction:column; gap:14px;">
      <input type="hidden" name="action" value="save_feature">
      <input type="hidden" name="feature_id" id="feat_id" value="0">

      <div class="form-group">
        <label class="form-label">Thuộc Danh Mục</label>
        <select name="category_id" id="feat_category_id" class="form-control" required>
          <?php foreach ($categories as $c): ?>
            <option value="<?= $c['id'] ?>"><?= htmlspecialchars($c['display_name']) ?></option>
          <?php endforeach; ?>
        </select>
      </div>

      <div class="form-group">
        <label class="form-label">Tên Chức Năng (Ví dụ: Menu V1, CheatExternal, Modskin Alock, Aim Head...)</label>
        <input type="text" name="display_name" id="feat_display_name" class="form-control" required placeholder="Tên chức năng">
      </div>

      <div class="form-group">
        <label class="form-label">Slug (tùy chọn)</label>
        <input type="text" name="slug" id="feat_slug" class="form-control" placeholder="menu-v1">
      </div>

      <div class="form-group">
        <label class="form-label">Trạng Thái Trên Ứng Dụng</label>
        <select name="status" id="feat_status" class="form-control">
          <option value="ready">🟢 Sẵn sàng (Cho phép tải và áp dụng)</option>
          <option value="unsupported">🔴 Chưa Hỗ Trợ (Khách bấm vào hiện: Chưa Hỗ Trợ)</option>
          <option value="no_file">⚪ Chưa có file trên server (Tự báo Chưa Hỗ Trợ)</option>
          <option value="loading">🟡 Đang bảo trì / cập nhật</option>
        </select>
      </div>

      <div class="form-group">
        <label class="form-label">Chọn File Có Sẵn (Từ Kho File Server)</label>
        <select name="file_id" id="feat_file_id" class="form-control">
          <option value="-1">-- Giữ nguyên file hiện tại --</option>
          <option value="0">❌ Không gán file (Chưa hỗ trợ)</option>
          <?php foreach ($allFiles as $fl): ?>
            <option value="<?= $fl['id'] ?>">📦 <?= htmlspecialchars($fl['display_name']) ?> (<?= htmlspecialchars($fl['original_name']) ?> - <?= number_format($fl['file_size']/1024, 1) ?> KB)</option>
          <?php endforeach; ?>
        </select>
        <div style="font-size:0.75rem; color:var(--color-text-muted); margin-top:4px;">
          Chọn file đã tải lên trước đó trên máy chủ, HOẶC nạp file mới ở ô bên dưới.
        </div>
      </div>

      <div class="form-group">
        <label class="form-label">Nạp File Mới (.3105, .bytes, .gzip, .unityfs, .json, .zip, .config)</label>
        <input type="file" name="feature_file" id="feat_file" class="form-control" accept=".3105,.bytes,.gzip,.unityfs,.json,.plist,.zip,.dat,.bin,.config,.txt,.dylib,.deb">
        <div style="font-size:0.75rem; color:var(--color-text-muted); margin-top:4px;">
          Để trống nếu muốn giữ nguyên hoặc đã chọn file có sẵn ở trên.
        </div>
      </div>

      <div class="form-group">
        <label class="form-label">Vị Trí Áp Dụng File Trong App Game (Target Path)</label>
        <select name="target_path" id="feat_target_path" class="form-control">
          <option value="Documents/">Documents/ (Assembly, localconfig, save data)</option>
          <option value="Documents/cached/">Documents/cached/ (Aim cache, hot updates)</option>
          <option value="Library/Preferences/">Library/Preferences/ (Config plist)</option>
          <option value="sing-box">Cấu hình sing-box (Mở qua sing-box app)</option>
        </select>
      </div>

      <div class="form-group">
        <label class="form-label">URL Ảnh Xem Trước / Preview (Cho Modskin)</label>
        <input type="url" name="preview_url" id="feat_preview_url" class="form-control" placeholder="https://...">
      </div>

      <div class="form-group">
        <label class="form-label">Thứ tự hiển thị</label>
        <input type="number" name="sort_order" id="feat_sort_order" class="form-control" value="1">
      </div>

      <div style="display:flex; justify-content:flex-end; gap:8px; margin-top:8px;">
        <button type="button" onclick="closeFeatureModal()" class="btn btn-secondary">Hủy</button>
        <button type="submit" class="btn btn-primary">Lưu Chức Năng</button>
      </div>
    </form>
  </div>
</div>

<script>
function openCategoryModal() {
  document.getElementById('cat_id').value = '0';
  document.getElementById('catModalTitle').innerText = 'Thêm Danh Mục Mới';
  document.getElementById('cat_display_name').value = '';
  document.getElementById('cat_slug').value = '';
  document.getElementById('cat_logo_url').value = '';
  document.getElementById('cat_description').value = '';
  document.getElementById('cat_sort_order').value = '1';
  document.getElementById('catModal').style.display = 'flex';
}

function editCategory(c) {
  document.getElementById('cat_id').value = c.id;
  document.getElementById('catModalTitle').innerText = 'Sửa Danh Mục: ' + c.display_name;
  document.getElementById('cat_display_name').value = c.display_name || '';
  document.getElementById('cat_slug').value = c.slug || '';
  document.getElementById('cat_logo_url').value = c.logo_url || '';
  document.getElementById('cat_description').value = c.description || '';
  document.getElementById('cat_sort_order').value = c.sort_order || '1';
  document.getElementById('catModal').style.display = 'flex';
}

function closeCategoryModal() {
  document.getElementById('catModal').style.display = 'none';
}

function openFeatureModal() {
  document.getElementById('feat_id').value = '0';
  document.getElementById('featModalTitle').innerText = 'Thêm Chức Năng Mới';
  document.getElementById('feat_display_name').value = '';
  document.getElementById('feat_slug').value = '';
  document.getElementById('feat_status').value = 'unsupported';
  document.getElementById('feat_file_id').value = '0';
  document.getElementById('feat_file').value = '';
  document.getElementById('feat_preview_url').value = '';
  document.getElementById('feat_target_path').value = 'Documents/';
  document.getElementById('feat_sort_order').value = '1';
  document.getElementById('featModal').style.display = 'flex';
}

function editFeature(f) {
  document.getElementById('feat_id').value = f.id;
  document.getElementById('featModalTitle').innerText = 'Sửa Chức Năng: ' + f.display_name;
  document.getElementById('feat_category_id').value = f.category_id;
  document.getElementById('feat_display_name').value = f.display_name || '';
  document.getElementById('feat_slug').value = f.slug || '';
  document.getElementById('feat_status').value = f.status || 'unsupported';
  document.getElementById('feat_file_id').value = f.file_id ? f.file_id : '0';
  document.getElementById('feat_file').value = '';
  document.getElementById('feat_preview_url').value = f.preview_url || '';
  document.getElementById('feat_target_path').value = f.target_path || 'Documents/';
  document.getElementById('feat_sort_order').value = f.sort_order || '1';
  document.getElementById('featModal').style.display = 'flex';
}

function closeFeatureModal() {
  document.getElementById('featModal').style.display = 'none';
}
</script>

<?php require_once ZEV_ROOT . '/admin/partials/footer.php'; ?>
