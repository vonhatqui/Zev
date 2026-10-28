<?php
/**
 * ZEV Admin — Quản lý Gói Bản Vá & File Game (Loader & Injector)
 * Cho phép tải 1 file chính (.3105 / Assembly), nhập pass file .3105 và đính kèm file localconfig.json
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
$currentGame = null;
foreach ($games as $g) {
    if ((int)$g['id'] === $selectedGameId) {
        $currentGame = $g;
        break;
    }
}
if (!$currentGame) {
    $currentGame = $games[0] ?? ['id' => 1, 'display_name' => 'Free Fire', 'bundle_id' => 'com.dts.freefireth'];
}

// Đảm bảo có category cho game hiện tại
$category = $db->fetchOne("SELECT id FROM feature_categories WHERE game_id = ? AND slug = 'menu-project'", [$selectedGameId]);
if (!$category) {
    $catId = $db->insert("
        INSERT INTO feature_categories (game_id, slug, display_name, description, sort_order, is_active)
        VALUES (?, 'menu-project', 'Menu Project', 'Bản vá chính của game', 1, 1)
    ", [$selectedGameId]);
} else {
    $catId = (int)$category['id'];
}

// 2. Xử lý Upload / Cập nhật Gói Bản Vá
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['action']) && $_POST['action'] === 'save_patch') {
    $displayName  = sanitizeString($_POST['display_name'] ?? 'Bản Vá Mới', 128);
    $filePassword = sanitizeString($_POST['file_password'] ?? '', 255);
    $targetPath   = sanitizeString($_POST['target_path'] ?? 'Documents/', 255);
    $selectedExistingMainId   = isset($_POST['existing_main_file_id']) ? (int)$_POST['existing_main_file_id'] : 0;
    $selectedExistingConfigId = isset($_POST['existing_config_file_id']) ? (int)$_POST['existing_config_file_id'] : 0;

    $uploadDir = ZEV_ROOT . '/uploads/files/';
    if (!is_dir($uploadDir)) {
        @mkdir($uploadDir, 0755, true);
    }

    $mainFileId = $selectedExistingMainId > 0 ? $selectedExistingMainId : null;
    $configFileId = $selectedExistingConfigId > 0 ? $selectedExistingConfigId : null;

    // A. Xử lý upload file bản vá chính
    if (isset($_FILES['main_file']) && $_FILES['main_file']['error'] !== UPLOAD_ERR_NO_FILE) {
        if ($_FILES['main_file']['error'] === UPLOAD_ERR_OK) {
            $origName = basename($_FILES['main_file']['name']);
            $ext      = strtolower(pathinfo($origName, PATHINFO_EXTENSION));
            $allowed  = ['3105', 'bytes', 'gzip', 'unityfs', 'json', 'plist', 'zip', 'dat', 'bin', 'config', 'txt', 'dll'];

            if (!in_array($ext, $allowed)) {
                $errorMsg = "File chính không đúng định dạng. Chỉ chấp nhận: " . implode(', ', $allowed);
            } else {
                $stored = 'zev_main_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
                $dest   = $uploadDir . $stored;

                if (move_uploaded_file($_FILES['main_file']['tmp_name'], $dest)) {
                    $size = filesize($dest);
                    $hash = hash_file('sha256', $dest);

                    $mainFileId = $db->insert("
                        INSERT INTO file_records (original_name, display_name, stored_filename, file_path, file_size, mime_type, checksum_sha256, game_id, target_path, file_password, status, uploaded_at, updated_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'active', NOW(), NOW())
                    ", [$origName, $displayName, $stored, $stored, $size, $ext, $hash, $selectedGameId, $targetPath, $filePassword ?: null]);
                } else {
                    $errorMsg = "Không thể lưu file chính vào thư mục uploads/.";
                }
            }
        } else {
            $errorMsg = "Lỗi khi tải file chính (Mã: " . $_FILES['main_file']['error'] . ")";
        }
    }

    // B. Xử lý upload file localconfig đi kèm nếu có
    if (empty($errorMsg) && isset($_FILES['config_file']) && $_FILES['config_file']['error'] !== UPLOAD_ERR_NO_FILE) {
        if ($_FILES['config_file']['error'] === UPLOAD_ERR_OK) {
            $origName = basename($_FILES['config_file']['name']);
            $ext      = strtolower(pathinfo($origName, PATHINFO_EXTENSION));
            $allowed  = ['json', 'txt', 'config', 'plist', 'bytes', 'dat'];

            if (!in_array($ext, $allowed)) {
                $errorMsg = "File cấu hình đi kèm chỉ chấp nhận định dạng: .json, .txt, .config, .plist";
            } else {
                $stored = 'zev_cfg_' . time() . '_' . bin2hex(random_bytes(4)) . '.' . $ext;
                $dest   = $uploadDir . $stored;

                if (move_uploaded_file($_FILES['config_file']['tmp_name'], $dest)) {
                    $size = filesize($dest);
                    $hash = hash_file('sha256', $dest);

                    $configFileId = $db->insert("
                        INSERT INTO file_records (original_name, display_name, stored_filename, file_path, file_size, mime_type, checksum_sha256, game_id, target_path, status, uploaded_at, updated_at)
                        VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'Documents/', 'active', NOW(), NOW())
                    ", [$origName, 'localconfig.json (' . $displayName . ')', $stored, $stored, $size, $ext, $hash, $selectedGameId]);
                } else {
                    $errorMsg = "Không thể lưu file localconfig vào thư mục uploads/.";
                }
            }
        }
    }

    // C. Lưu vào bảng features (bản vá active của game)
    if (empty($errorMsg) && $mainFileId) {
        // Cập nhật lại password trên main file record nếu có
        $db->execute("UPDATE file_records SET file_password = ?, config_file_id = ? WHERE id = ?", [$filePassword ?: null, $configFileId, $mainFileId]);

        // Tìm feature chính của game
        $feat = $db->fetchOne("SELECT id FROM features WHERE category_id = ? ORDER BY id ASC LIMIT 1", [$catId]);
        if ($feat) {
            $db->execute("
                UPDATE features 
                SET display_name = ?, status = 'ready', file_id = ?, file_password = ?, config_file_id = ?, updated_at = NOW()
                WHERE id = ?
            ", [$displayName, $mainFileId, $filePassword ?: null, $configFileId, $feat['id']]);
        } else {
            $db->execute("
                INSERT INTO features (category_id, slug, display_name, description, status, file_id, file_password, config_file_id, sort_order, created_at, updated_at)
                VALUES (?, 'main-patch', ?, 'Bản vá chính', 'ready', ?, ?, ?, 1, NOW(), NOW())
            ", [$catId, $displayName, $mainFileId, $filePassword ?: null, $configFileId]);
        }
        $successMsg = "Đã lưu và kích hoạt gói bản vá thành công cho {$currentGame['display_name']}!";
    } elseif (empty($errorMsg) && !$mainFileId) {
        $errorMsg = "Vui lòng chọn hoặc tải lên ít nhất 1 file bản vá chính.";
    }
}

// 3. Xử lý gỡ bỏ bản vá active
if (isset($_GET['disable_patch'])) {
    $db->execute("UPDATE features SET status = 'unsupported', file_id = NULL, file_password = NULL, config_file_id = NULL WHERE category_id = ?", [$catId]);
    $successMsg = "Đã gỡ bản vá active khỏi {$currentGame['display_name']}.";
}

// 4. Lấy gói bản vá active hiện tại của Game
$activePatch = $db->fetchOne("
    SELECT f.id as feature_id, f.display_name, f.status, f.file_id, f.file_password, f.config_file_id,
           fr.original_name as main_file_name, fr.file_size as main_file_size, fr.target_path as main_target_path, fr.checksum_sha256 as main_checksum, fr.uploaded_at,
           cfr.original_name as config_file_name, cfr.file_size as config_file_size
    FROM features f
    LEFT JOIN file_records fr ON fr.id = f.file_id
    LEFT JOIN file_records cfr ON cfr.id = f.config_file_id
    WHERE f.category_id = ? AND f.file_id IS NOT NULL AND f.status = 'ready'
    ORDER BY f.id ASC LIMIT 1
", [$catId]);

// 5. Danh sách toàn bộ file trong kho để chọn nhanh
$filesList = $db->fetchAll("
    SELECT id, original_name, display_name, file_size, uploaded_at, file_password
    FROM file_records 
    WHERE status = 'active'
    ORDER BY id DESC
");

$pageTitle  = 'Quản lý Bản Vá & File';
$activePage = 'features';
require_once ZEV_ROOT . '/admin/partials/header.php';
?>

<div style="display:flex; justify-content:space-between; align-items:center; margin-bottom:20px; flex-wrap:wrap; gap:12px;">
  <div>
    <h2 style="font-size:1.3rem; font-weight:700; color:#fff; margin-bottom:4px;">
      <i class="fa-solid fa-sliders" style="color:var(--color-primary); margin-right:8px;"></i> Quản lý Bản Vá & Nạp File
    </h2>
    <p style="color:var(--color-text-muted); font-size:0.88rem;">
      Chế độ 1 File: Mỗi game chỉ cần nạp 1 file bản vá chính (gói .3105 hoặc Assembly), nhập pass giải mã và file localconfig.json đi kèm nếu có.
    </p>
  </div>
</div>

<?php if ($successMsg): ?>
  <div class="alert alert-success" style="margin-bottom:16px;">
    <i class="fa-solid fa-circle-check"></i> <?= htmlspecialchars($successMsg) ?>
  </div>
<?php endif; ?>
<?php if ($errorMsg): ?>
  <div class="alert alert-danger" style="margin-bottom:16px;">
    <i class="fa-solid fa-circle-exclamation"></i> <?= htmlspecialchars($errorMsg) ?>
  </div>
<?php endif; ?>

<!-- Tabs chọn Game có avatar logo chính thức -->
<div style="display:flex; gap:12px; margin-bottom:24px;">
  <?php foreach ($games as $g): ?>
    <?php 
      $isActive = ($selectedGameId == $g['id']); 
      $logo = !empty($g['logo_url']) ? $g['logo_url'] : ($g['id'] == 1 ? 'https://i.ibb.co/7J4qj2kM/IMG-4819.webp' : 'https://i.ibb.co/spHGtVNh/IMG-4818.png');
    ?>
    <a href="?game_id=<?= $g['id'] ?>" 
       class="btn <?= $isActive ? 'btn-primary' : 'btn-secondary' ?>" 
       style="display:flex; align-items:center; gap:12px; padding:10px 18px; border-radius:10px; text-decoration:none; transition:all 0.2s;">
      <img src="<?= htmlspecialchars($logo) ?>" alt="" style="width:28px; height:28px; border-radius:6px; object-fit:cover;">
      <div style="text-align:left;">
        <div style="font-weight:700; font-size:0.95rem;"><?= htmlspecialchars($g['display_name']) ?></div>
        <div style="font-size:0.75rem; opacity:0.8; font-family:var(--font-mono);"><?= htmlspecialchars($g['bundle_id']) ?></div>
      </div>
    </a>
  <?php endforeach; ?>
</div>

<div style="display:grid; grid-template-columns: 1fr 1.15fr; gap:20px; align-items:start;">

  <!-- CỘT 1: BẢN VÁ ĐANG ACTIVE -->
  <div class="card">
    <div class="card-header">
      <span class="card-title">
        <i class="fa-solid fa-circle-check" style="color:var(--color-success); margin-right:6px;"></i> Bản Vá Đang Kích Hoạt (App Sẽ Tải)
      </span>
      <?php if ($activePatch): ?>
        <span class="badge badge-success"><i class="fa-solid fa-bolt"></i> Sẵn sàng nạp</span>
      <?php else: ?>
        <span class="badge badge-warning"><i class="fa-solid fa-triangle-exclamation"></i> Chưa có file</span>
      <?php endif; ?>
    </div>

    <div class="card-body">
      <?php if ($activePatch): ?>
        <div style="margin-bottom:16px;">
          <div style="font-size:0.8rem; color:var(--color-text-muted); text-transform:uppercase; font-weight:700; margin-bottom:4px;">Tên Bản Vá</div>
          <div style="font-size:1.15rem; font-weight:700; color:#fff;"><?= htmlspecialchars($activePatch['display_name']) ?></div>
        </div>

        <div style="background:var(--color-surface2); border:1px solid var(--color-border); border-radius:8px; padding:14px; margin-bottom:16px;">
          <div style="display:flex; align-items:center; gap:10px; margin-bottom:10px;">
            <i class="fa-solid fa-file-code" style="font-size:1.5rem; color:var(--color-primary);"></i>
            <div>
              <div style="font-weight:700; color:#fff; font-size:0.95rem;"><?= htmlspecialchars($activePatch['main_file_name']) ?></div>
              <div style="font-size:0.78rem; color:var(--color-text-muted);">
                Dung lượng: <strong><?= number_format($activePatch['main_file_size'] / 1024, 1) ?> KB</strong> &bull; Đích: <code><?= htmlspecialchars($activePatch['main_target_path'] ?? 'Documents/') ?></code>
              </div>
            </div>
          </div>

          <div style="font-size:0.8rem; color:var(--color-text-muted); border-top:1px dashed var(--color-border); padding-top:8px;">
            <span><i class="fa-solid fa-lock"></i> Mật khẩu file .3105:</span>
            <?php if (!empty($activePatch['file_password'])): ?>
              <span class="badge badge-primary" style="font-family:var(--font-mono); font-size:0.85rem; padding:3px 8px; margin-left:6px;">
                <?= htmlspecialchars($activePatch['file_password']) ?>
              </span>
            <?php else: ?>
              <span style="color:var(--color-text-dim); margin-left:6px;">(Không có mật khẩu)</span>
            <?php endif; ?>
          </div>
        </div>

        <?php if (!empty($activePatch['config_file_name'])): ?>
          <div style="background:var(--color-surface2); border:1px solid var(--color-border); border-radius:8px; padding:14px; margin-bottom:16px;">
            <div style="display:flex; align-items:center; gap:10px;">
              <i class="fa-solid fa-file-lines" style="font-size:1.4rem; color:var(--color-warning);"></i>
              <div>
                <div style="font-weight:700; color:#fff; font-size:0.9rem;">File localconfig.json đi kèm:</div>
                <div style="font-size:0.8rem; color:var(--color-text-muted);">
                  <code><?= htmlspecialchars($activePatch['config_file_name']) ?></code> &bull; <?= number_format($activePatch['config_file_size'] / 1024, 1) ?> KB &bull; Nạp vào: <code>Documents/</code>
                </div>
              </div>
            </div>
          </div>
        <?php else: ?>
          <div style="padding:10px 14px; border:1px dashed var(--color-border); border-radius:8px; font-size:0.82rem; color:var(--color-text-dim); margin-bottom:16px;">
            <i class="fa-solid fa-info-circle"></i> Chưa đính kèm file localconfig.json (Chỉ nạp file chính).
          </div>
        <?php endif; ?>

        <div style="display:flex; justify-content:space-between; align-items:center; border-top:1px solid var(--color-border); padding-top:14px;">
          <span style="font-size:0.78rem; color:var(--color-text-dim);">
            Cập nhật: <?= date('d/m/Y H:i', strtotime($activePatch['uploaded_at'] ?? 'now')) ?>
          </span>
          <a href="?game_id=<?= $selectedGameId ?>&disable_patch=1" 
             onclick="return confirm('Bạn có chắc muốn gỡ bản vá này? App Zev sẽ báo chưa có file.')" 
             class="btn btn-danger btn-sm">
            <i class="fa-solid fa-trash-can"></i> Gỡ Bản Vá
          </a>
        </div>
      <?php else: ?>
        <div style="text-align:center; padding:36px 20px; color:var(--color-text-muted);">
          <div style="font-size:2.8rem; color:var(--color-text-dim); margin-bottom:12px;">
            <i class="fa-solid fa-cloud-arrow-down"></i>
          </div>
          <p style="font-weight:600; color:#fff; margin-bottom:6px;">Chưa có bản vá nào được kích hoạt</p>
          <p style="font-size:0.82rem; margin-bottom:0;">
            Khi người dùng mở app Zev và bấm <strong>Loader</strong>, app sẽ báo không tìm thấy file. Hãy upload 1 file ở form bên phải để kích hoạt.
          </p>
        </div>
      <?php endif; ?>
    </div>
  </div>

  <!-- CỘT 2: FORM TẢI LÊN & KÍCH HOẠT BẢN VÁ MỚI -->
  <div class="card">
    <div class="card-header">
      <span class="card-title">
        <i class="fa-solid fa-cloud-arrow-up" style="color:var(--color-primary); margin-right:6px;"></i> Nạp Bản Vá Mới (Dùng 1 File Duy Nhất)
      </span>
    </div>

    <div class="card-body">
      <form method="POST" action="?game_id=<?= $selectedGameId ?>" enctype="multipart/form-data">
        <input type="hidden" name="action" value="save_patch">

        <div class="form-group" style="margin-bottom:16px;">
          <label class="form-label" style="font-weight:600;">
            Tên Hiển Thị Bản Vá <span style="color:var(--color-danger);">*</span>
          </label>
          <input type="text" name="display_name" class="form-control" required
                 value="<?= htmlspecialchars($activePatch['display_name'] ?? ('Bản Vá ' . $currentGame['display_name'])) ?>" 
                 placeholder="Ví dụ: CheatVN External, Mod Menu Assembly...">
        </div>

        <!-- 1. File chính -->
        <div class="form-group" style="margin-bottom:18px;">
          <label class="form-label" style="font-weight:600; display:flex; justify-content:space-between;">
            <span><i class="fa-solid fa-file-code"></i> 1. File Bản Vá Chính (.3105 / Assembly) <span style="color:var(--color-danger);">*</span></span>
            <span style="font-size:0.75rem; color:var(--color-text-muted); font-weight:normal;">Chỉ up 1 file duy nhất</span>
          </label>
          <input type="file" name="main_file" class="form-control" accept=".3105,.bytes,.dll,.unityfs,.zip,.dat,.bin">
          <small class="form-hint" style="color:var(--color-text-muted); font-size:0.78rem; display:block; margin-top:4px;">
            Chấp nhận: Gói <code>.3105</code> (3105-2.0 package), <code>.bytes</code> (Assembly-CSharp), <code>.dll</code>, <code>.zip</code>.
          </small>

          <?php if (!empty($filesList)): ?>
            <div style="margin-top:8px;">
              <label style="font-size:0.78rem; color:var(--color-text-muted); margin-bottom:2px; display:block;">Hoặc chọn lại từ kho file đã có:</label>
              <select name="existing_main_file_id" class="form-control" style="font-size:0.85rem;">
                <option value="0">-- Tải file mới từ máy tính ở trên --</option>
                <?php foreach ($filesList as $rf): ?>
                  <option value="<?= $rf['id'] ?>" <?= ($activePatch && $activePatch['file_id'] == $rf['id']) ? 'selected' : '' ?>>
                    <?= htmlspecialchars($rf['original_name']) ?> (<?= number_format($rf['file_size']/1024, 1) ?> KB) - <?= date('d/m', strtotime($rf['uploaded_at'])) ?>
                  </option>
                <?php endforeach; ?>
              </select>
            </div>
          <?php endif; ?>
        </div>

        <!-- 2. Mật khẩu file .3105 -->
        <div class="form-group" style="margin-bottom:18px; background:var(--color-surface2); padding:12px; border-radius:8px; border:1px solid var(--color-border);">
          <label class="form-label" style="font-weight:600;">
            <i class="fa-solid fa-key" style="color:var(--color-warning);"></i> 2. Mật Khẩu Giải Mã File .3105 (Nếu Có)
          </label>
          <input type="text" name="file_password" class="form-control" 
                 value="<?= htmlspecialchars($activePatch['file_password'] ?? '') ?>"
                 placeholder="Nhập mật khẩu nếu gói .3105 của bạn được đặt pass">
          <small class="form-hint" style="color:var(--color-text-muted); font-size:0.76rem; display:block; margin-top:4px;">
            Nếu file .3105 có mật khẩu, app Zev sẽ tự động dùng pass này để giải nạp vào game mà người dùng không cần gõ thủ công. Để trống nếu file không có pass.
          </small>
        </div>

        <!-- 3. File localconfig.json đi kèm -->
        <div class="form-group" style="margin-bottom:18px; background:var(--color-surface2); padding:12px; border-radius:8px; border:1px solid var(--color-border);">
          <label class="form-label" style="font-weight:600;">
            <i class="fa-solid fa-file-lines" style="color:var(--color-primary);"></i> 3. File localconfig.json Đi Kèm (Tùy Chọn)
          </label>
          <input type="file" name="config_file" class="form-control" accept=".json,.txt,.config,.plist">
          <small class="form-hint" style="color:var(--color-text-muted); font-size:0.76rem; display:block; margin-top:4px;">
            Dành cho file Assembly cần nạp kèm file <code>localconfig.json</code> vào Documents của game.
          </small>

          <?php if (!empty($filesList)): ?>
            <div style="margin-top:6px;">
              <select name="existing_config_file_id" class="form-control" style="font-size:0.82rem;">
                <option value="0">-- Không dùng file config hoặc tải file mới ở trên --</option>
                <?php foreach ($filesList as $rf): ?>
                  <option value="<?= $rf['id'] ?>" <?= ($activePatch && $activePatch['config_file_id'] == $rf['id']) ? 'selected' : '' ?>>
                    Gán file: <?= htmlspecialchars($rf['original_name']) ?> (<?= number_format($rf['file_size']/1024, 1) ?> KB)
                  </option>
                <?php endforeach; ?>
              </select>
            </div>
          <?php endif; ?>
        </div>

        <div class="form-group" style="margin-bottom:20px;">
          <label class="form-label" style="font-weight:600;">Vị Trí Đích Trong Game (Target Path)</label>
          <input type="text" name="target_path" class="form-control" value="Documents/" readonly style="background:rgba(255,255,255,0.05);">
          <small class="form-hint" style="color:var(--color-text-dim); font-size:0.75rem;">Mặc định nạp thẳng vào Documents container của Free Fire.</small>
        </div>

        <button type="submit" class="btn btn-primary" style="width:100%; padding:12px; font-weight:700; font-size:0.95rem;">
          <i class="fa-solid fa-cloud-arrow-up"></i> Lưu & Kích Hoạt Bản Vá Ngay
        </button>
      </form>
    </div>
  </div>

</div>

<?php require_once ZEV_ROOT . '/admin/partials/footer.php'; ?>
