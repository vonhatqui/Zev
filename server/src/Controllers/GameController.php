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
    public function index(): never
    {
        $games = $this->db->fetchAll(
            "SELECT id, bundle_id, display_name, short_name, logo_url, description, sort_order 
             FROM games WHERE is_active = 1 ORDER BY sort_order ASC"
        );

        jsonResponse(200, 'success', 'OK', ['games' => $games]);
    }

    /**
     * GET /api/v1/games/{id}/categories
     */
    public function categories(int $gameId): never
    {
        $game = $this->db->fetchOne(
            "SELECT id, display_name FROM games WHERE id = ? AND is_active = 1",
            [$gameId]
        );

        if (!$game) {
            jsonResponse(404, 'error', 'Game không tồn tại.');
        }

        $categories = $this->db->fetchAll(
            "SELECT id, slug, display_name, logo_url, description, sort_order 
             FROM feature_categories 
             WHERE game_id = ? AND is_active = 1 
             ORDER BY sort_order ASC",
            [$gameId]
        );

        // Đếm số tính năng ready trong mỗi category
        foreach ($categories as &$cat) {
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

        jsonResponse(200, 'success', 'OK', [
            'game'       => $game,
            'categories' => $categories,
        ]);
    }

    /**
     * GET /api/v1/games/{id}/features
     */
    public function features(int $gameId): never
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
                    f.preview_url, f.sort_order,
                    fc.id as category_id, fc.slug as category_slug, fc.display_name as category_name,
                    fr.file_version, fr.file_size
             FROM features f
             JOIN feature_categories fc ON fc.id = f.category_id
             LEFT JOIN file_records fr ON fr.id = f.file_id AND fr.status = 'active'
             WHERE fc.game_id = ? AND f.is_active = 1 AND fc.is_active = 1
             ORDER BY fc.sort_order ASC, f.sort_order ASC",
            [$gameId]
        );

        jsonResponse(200, 'success', 'OK', ['features' => $features]);
    }

    /**
     * GET /api/v1/features/{id}
     */
    public function feature(int $featureId): never
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
