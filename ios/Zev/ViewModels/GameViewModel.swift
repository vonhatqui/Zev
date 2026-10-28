import SwiftUI

// MARK: - GameViewModel
// Quản lý trạng thái tải danh sách game, danh mục và tính năng

@MainActor
final class GameViewModel: ObservableObject {
    @Published var games: [Game] = []
    @Published var selectedGame: Game? = nil
    @Published var categories: [FeatureCategory] = []
    @Published var features: [Feature] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    
    func fetchGames() async {
        isLoading = true
        errorMessage = nil
        do {
            games = try await APIService.shared.fetchGames()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func fetchGameDetails(gameId: Int) async {
        isLoading = true
        errorMessage = nil
        do {
            async let catTask  = APIService.shared.fetchCategories(for: gameId)
            async let featTask = APIService.shared.fetchFeatures(for: gameId)
            
            let (cat, feat) = try await (catTask, featTask)
            categories = cat.categories
            features = feat
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
