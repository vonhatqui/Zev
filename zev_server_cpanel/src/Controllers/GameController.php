<?php
/**
 * ZEV — Game Controller
 * Trả về danh sách game, danh mục và tính năng
 */

namespace Zev\Controllers;

use Zev\Config\Database;

class GameController
{
    private Database $db;

    public function __construct()
    {
        $this->db = Database::getInstance();
    }

    /**
     * GET /api/v1/games
     */
    public function index(): void
    {
        $games = $this->db->fetchAll(
            "SELECT id, bundle_id, display_name, short_name, logo_url, description, sort_order 
             FROM games WHERE is_active = 1 ORDER BY sort_order ASC"
        );

        foreach ($games as &$g) {
            $g['id'] = (int)$g['id'];
            $g['sort_order'] = (int)$g['sort_order'];
        }
        unset($g);

        jsonResponse(200, 'success', 'OK', ['games' => $games]);
    }

    /**
     * GET /api/v1/games/{id}/categories
     */
    public function categories(int $gameId): void
    {
        $game = $this->db->fetchOne(
            "SELECT id, display_name FROM games WHERE id = ? AND is_active = 1",
            [$gameId]
        );

        if (!$game) {
            jsonResponse(404, 'error', 'Game không tồn tại.');
        }

        $game['id'] = (int)$game['id'];

        $categories = $this->db->fetchAll(
            "SELECT id, slug, display_name, logo_url, description, sort_order 
             FROM feature_categories 
             WHERE game_id = ? AND is_active = 1 
             ORDER BY sort_order ASC",
            [$gameId]
        );

        // Đếm số tính năng ready trong mỗi category và chuẩn hóa kiểu số
        foreach ($categories as &$cat) {
            $cat['id'] = (int)$cat['id'];
            $cat['sort_order'] = (int)$cat['sort_order'];
            $counts = $this->db->fetchOne(
                "SELECT 
                    COUNT(*) as total,
                    SUM(CASE WHEN status = 'ready' THEN 1 ELSE 0 END) as ready
                 FROM features WHERE category_id = ? AND is_active = 1",
                [$cat['id']]
            );
            $cat['feature_count'] = (int) ($counts['total'] ?? 0);
            $cat['ready_count']   = (int) ($counts['ready'] ?? 0);
        }
        unset($cat);

        jsonResponse(200, 'success', 'OK', [
            'game'       => $game,
            'categories' => $categories,
        ]);
    }

    /**
     * GET /api/v1/games/{id}/features
     */
    public function features(int $gameId): void
    {
        $game = $this->db->fetchOne(
            "SELECT id FROM games WHERE id = ? AND is_active = 1",
            [$gameId]
        );

        if (!$game) {
            jsonResponse(404, 'error', 'Game không tồn tại.');
        }

        $features = $this->db->fetchAll(
            "SELECT f.id, f.slug, f.display_name, f.description, f.status, 
                    f.file_id, f.preview_url, f.sort_order, f.file_password, f.config_file_id,
                    fc.id as category_id, fc.slug as category_slug, fc.display_name as category_name,
                    fr.original_name as file_name, fr.file_version, fr.file_size, fr.target_path, fr.checksum_sha256,
                    cfr.original_name as config_file_name, cfr.file_size as config_file_size, cfr.target_path as config_target_path
             FROM features f
             JOIN feature_categories fc ON fc.id = f.category_id
             LEFT JOIN file_records fr ON fr.id = f.file_id AND fr.status = 'active'
             LEFT JOIN file_records cfr ON cfr.id = f.config_file_id AND cfr.status = 'active'
             WHERE fc.game_id = ? AND f.is_active = 1 AND fc.is_active = 1
             ORDER BY fc.sort_order ASC, f.sort_order ASC",
            [$gameId]
        );

        // Chuẩn hóa kiểu dữ liệu cho Swift API
        $activePatch = null;
        foreach ($features as &$f) {
            $f['id'] = (int)$f['id'];
            $f['category_id'] = (int)$f['category_id'];
            $f['sort_order'] = (int)$f['sort_order'];
            $f['file_id'] = $f['file_id'] !== null ? (int)$f['file_id'] : null;
            $f['file_size'] = $f['file_size'] !== null ? (int)$f['file_size'] : null;
            $f['config_file_id'] = $f['config_file_id'] !== null ? (int)$f['config_file_id'] : null;
            $f['config_file_size'] = !empty($f['config_file_size']) ? (int)$f['config_file_size'] : null;

            if ($activePatch === null && $f['status'] === 'ready' && $f['file_id'] !== null) {
                $pass = $f['file_password'];
                if (empty($pass) && !empty($f['file_name']) && str_ends_with(strtolower($f['file_name']), '.3105')) {
                    $pass = 'OG';
                }
                $activePatch = [
                    'id'               => $f['id'],
                    'display_name'     => $f['display_name'],
                    'file_id'          => $f['file_id'],
                    'file_name'        => $f['file_name'],
                    'file_size'        => $f['file_size'],
                    'target_path'      => $f['target_path'] ?? 'Documents/',
                    'file_password'    => $pass,
                    'config_file_id'   => $f['config_file_id'],
                    'config_file_name' => $f['config_file_name'] ?? null,
                    'config_file_size' => $f['config_file_size'] ?? null,
                    'config_target_path'=> $f['config_target_path'] ?? 'Documents/',
                    'checksum_sha256'  => $f['checksum_sha256'],
                ];
            }
        }
        unset($f);

        jsonResponse(200, 'success', 'OK', [
            'features'     => $features,
            'active_patch' => $activePatch
        ]);
    }

    /**
     * GET /api/v1/games/{id}/patch
     * Lấy gói bản vá active duy nhất để Loader nạp vào Documents
     */
    public function activePatch(int $gameId): void
    {
        $game = $this->db->fetchOne("SELECT id, bundle_id, display_name FROM games WHERE id = ? AND is_active = 1", [$gameId]);
        if (!$game) {
            jsonResponse(404, 'error', 'Game không tồn tại.');
        }

        $feature = $this->db->fetchOne("
            SELECT f.id, f.slug, f.display_name, f.description, f.status, f.file_id, f.file_password, f.config_file_id,
                   fr.original_name as file_name, fr.file_size, fr.target_path, fr.checksum_sha256,
                   cfr.original_name as config_file_name, cfr.file_size as config_file_size, cfr.target_path as config_target_path
            FROM features f
            JOIN feature_categories fc ON fc.id = f.category_id
            LEFT JOIN file_records fr ON fr.id = f.file_id AND fr.status = 'active'
            LEFT JOIN file_records cfr ON cfr.id = f.config_file_id AND cfr.status = 'active'
            WHERE fc.game_id = ? AND f.is_active = 1 AND f.status = 'ready' AND f.file_id IS NOT NULL
            ORDER BY f.sort_order ASC, f.id DESC
            LIMIT 1
        ", [$gameId]);

        if (!$feature) {
            // Fallback: tìm file_record mới nhất gán cho game
            $fr = $this->db->fetchOne("
                SELECT fr.id as file_id, fr.original_name as file_name, fr.file_size, fr.target_path, fr.checksum_sha256, fr.file_password, fr.config_file_id
                FROM file_records fr
                WHERE fr.game_id = ? AND fr.status = 'active'
                ORDER BY fr.id DESC
                LIMIT 1
            ", [$gameId]);
            if ($fr) {
                $cfr = null;
                if (!empty($fr['config_file_id'])) {
                    $cfr = $this->db->fetchOne("SELECT id, original_name, file_size, target_path FROM file_records WHERE id = ?", [$fr['config_file_id']]);
                }
                $feature = [
                    'id'               => 1,
                    'display_name'     => 'Bản Vá ' . $game['display_name'],
                    'status'           => 'ready',
                    'file_id'          => $fr['file_id'],
                    'file_password'    => $fr['file_password'] ?? null,
                    'config_file_id'   => $fr['config_file_id'] ?? null,
                    'file_name'        => $fr['file_name'],
                    'file_size'        => $fr['file_size'],
                    'target_path'      => $fr['target_path'] ?? 'Documents/',
                    'checksum_sha256'  => $fr['checksum_sha256'],
                    'config_file_name' => $cfr['original_name'] ?? null,
                    'config_file_size' => $cfr['file_size'] ?? null,
                    'config_target_path'=> $cfr['target_path'] ?? 'Documents/',
                ];
            }
        }

        if (!$feature) {
            jsonResponse(200, 'success', 'Chưa có bản vá nào được gán cho game này.', [
                'has_patch' => false,
                'patch'     => null
            ]);
        }

        jsonResponse(200, 'success', 'OK', [
            'has_patch' => true,
            'patch'     => [
                'id'                 => (int)$feature['id'],
                'display_name'       => $feature['display_name'],
                'status'             => $feature['status'] ?? 'ready',
                'file_id'            => (int)$feature['file_id'],
                'file_name'          => $feature['file_name'],
                'file_size'          => (int)$feature['file_size'],
                'target_path'        => $feature['target_path'] ?? 'Documents/',
                'checksum_sha256'    => $feature['checksum_sha256'],
                'file_password'      => !empty($feature['file_password']) ? $feature['file_password'] : (!empty($feature['file_name']) && str_ends_with(strtolower($feature['file_name']), '.3105') ? 'OG' : null),
                'config_file_id'     => !empty($feature['config_file_id']) ? (int)$feature['config_file_id'] : null,
                'config_file_name'   => $feature['config_file_name'] ?? null,
                'config_file_size'   => !empty($feature['config_file_size']) ? (int)$feature['config_file_size'] : null,
                'config_target_path' => $feature['config_target_path'] ?? 'Documents/',
            ]
        ]);
    }

    /**
     * GET /api/v1/features/{id}
     */
    public function feature(int $featureId): void
    {
        $feature = $this->db->fetchOne(
            "SELECT f.id, f.slug, f.display_name, f.description, f.status, 
                    f.preview_url, f.category_id,
                    fc.display_name as category_name, fc.game_id,
                    g.display_name as game_name, g.bundle_id,
                    fr.id as file_id, fr.display_name as file_name, 
                    fr.file_size, fr.file_version, fr.checksum_sha256, fr.mime_type
             FROM features f
             JOIN feature_categories fc ON fc.id = f.category_id
             JOIN games g ON g.id = fc.game_id
             LEFT JOIN file_records fr ON fr.id = f.file_id AND fr.status = 'active'
             WHERE f.id = ? AND f.is_active = 1",
            [$featureId]
        );

        if (!$feature) {
            jsonResponse(404, 'error', 'Tính năng không tồn tại.');
        }

        jsonResponse(200, 'success', 'OK', ['feature' => $feature]);
    }
}
