import SwiftUI

// MARK: - GameListView
// Danh sách các tựa game được hỗ trợ tối ưu trong Zev

struct GameListView: View {
    @State private var games: [Game] = []
    @State private var searchQuery: String = ""
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    
    var filteredGames: [Game] {
        if searchQuery.isEmpty {
            return games
        } else {
            return games.filter {
                $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
                $0.shortName.localizedCaseInsensitiveContains(searchQuery) ||
                $0.bundleId.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ZevTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Header & Search
                    VStack(spacing: 12) {
                        HStack {
                            Text("Game & Tiện ích")
                                .font(ZevTheme.Typography.title(22))
                                .foregroundColor(ZevTheme.Colors.text)
                            Spacer()
                        }
                        
                        // Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(ZevTheme.Colors.textMuted)
                            
                            TextField("Tìm kiếm tựa game...", text: $searchQuery)
                                .font(ZevTheme.Typography.body(14))
                                .foregroundColor(ZevTheme.Colors.text)
                            
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(ZevTheme.Colors.textDim)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(ZevTheme.Colors.surface2)
                        .cornerRadius(ZevTheme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                .stroke(ZevTheme.Colors.border, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Content
                    if isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: ZevTheme.Colors.primary))
                            .scaleEffect(1.2)
                        Spacer()
                    } else if let error = errorMessage {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "wifi.exclamationmark")
                                .font(.system(size: 40))
                                .foregroundColor(ZevTheme.Colors.danger)
                            Text(error)
                                .font(ZevTheme.Typography.body(14))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                            ZevButton(title: "Thử lại", style: .secondary, isFullWidth: false) {
                                Task { await loadGames() }
                            }
                        }
                        Spacer()
                    } else if filteredGames.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "gamecontroller")
                                .font(.system(size: 44))
                                .foregroundColor(ZevTheme.Colors.textDim)
                            Text("Không tìm thấy game nào phù hợp.")
                                .font(ZevTheme.Typography.body(14))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                        }
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredGames) { game in
                                    NavigationLink(destination: GameDetailView(game: game)) {
                                        gameCard(game)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .task {
                await loadGames()
            }
            .refreshable {
                await loadGames()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Game Card View
    private func gameCard(_ game: Game) -> some View {
        ZevCard {
            HStack(spacing: 14) {
                // Game Logo
                AsyncImage(url: URL(string: game.logoUrl ?? "")) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    default:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(ZevTheme.Colors.surface3)
                                .frame(width: 54, height: 54)
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 24))
                                .foregroundColor(ZevTheme.Colors.primary)
                        }
                    }
                }
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(game.displayName)
                        .font(ZevTheme.Typography.heading(15))
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    if let desc = game.description, !desc.isEmpty {
                        Text(desc)
                            .font(ZevTheme.Typography.caption(12))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                            .lineLimit(2)
                    } else {
                        Text(game.bundleId)
                            .font(ZevTheme.Typography.mono(11))
                            .foregroundColor(ZevTheme.Colors.textDim)
                    }
                }
                
                Spacer()
                
                // Arrow
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(ZevTheme.Colors.textDim)
            }
        }
    }
    
    private func loadGames() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetched = try await APIService.shared.fetchGames()
            games = fetched
        } catch {
            errorMessage = "Không thể tải danh sách game: \(error.localizedDescription)"
        }
        isLoading = false
    }
}
