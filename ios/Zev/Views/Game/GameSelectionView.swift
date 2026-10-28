import SwiftUI

// MARK: - GameSelectionView
// Giao diện Chọn Game: Free Fire Thường (com.dts.freefireth) vs Free Fire MAX (com.dts.freefiremax)
// Hiển thị trạng thái "Sẵn sàng" hoặc "Chưa Cài Đặt" ở cuối mỗi card

struct GameSelectionView: View {
    @EnvironmentObject var appState: AppStateManager
    
    @State private var ffthInstalled: Bool = false
    @State private var ffmaxInstalled: Bool = false
    @State private var isChecking: Bool = false
    @State private var showWarningAlert: Bool = false
    @State private var pendingSelectedGame: Game? = nil
    
    // 2 Game mặc định
    private let ffthGame = Game(
        id: 1,
        bundleId: "com.dts.freefireth",
        displayName: "Free Fire Thường",
        shortName: "FFTH",
        logoUrl: AppConfig.GameLogos.freeFireTH,
        description: "Bản Free Fire tiêu chuẩn Việt Nam",
        sortOrder: 1
    )
    
    private let ffmaxGame = Game(
        id: 2,
        bundleId: "com.dts.freefiremax",
        displayName: "Free Fire MAX",
        shortName: "FFMAX",
        logoUrl: AppConfig.GameLogos.freeFireMAX,
        description: "Bản Free Fire MAX đồ họa cao cấp",
        sortOrder: 2
    )
    
    var body: some View {
        ZStack {
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            // Background ambient lights
            VStack {
                Circle()
                    .fill(ZevTheme.Colors.primary.opacity(0.14))
                    .blur(radius: 90)
                    .frame(width: 320, height: 320)
                    .offset(y: -90)
                Spacer()
            }
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // MARK: - Header
                    VStack(spacing: 12) {
                        // Logo không viền tím
                        AsyncImage(url: URL(string: AppConfig.appLogoURL)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable().aspectRatio(contentMode: .fit).frame(width: 76, height: 76)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                            default:
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(ZevTheme.Colors.primary)
                            }
                        }
                        
                        VStack(spacing: 4) {
                            Text("CHỌN PHIÊN BẢN GAME")
                                .font(ZevTheme.Typography.title(20))
                                .foregroundStyle(ZevTheme.Gradients.primary)
                                .tracking(1.2)
                            
                            Text("Chọn tựa game bạn muốn áp dụng chức năng và bản vá")
                                .font(ZevTheme.Typography.body(13))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                        }
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Game Cards List
                    VStack(spacing: 18) {
                        
                        // 1. Free Fire Thường (com.dts.freefireth)
                        gameCard(
                            game: ffthGame,
                            isInstalled: ffthInstalled,
                            badgeColor: ffthInstalled ? ZevTheme.Colors.success : ZevTheme.Colors.warning
                        ) {
                            handleSelectGame(ffthGame, isInstalled: ffthInstalled)
                        }
                        
                        // 2. Free Fire MAX (com.dts.freefiremax)
                        gameCard(
                            game: ffmaxGame,
                            isInstalled: ffmaxInstalled,
                            badgeColor: ffmaxInstalled ? ZevTheme.Colors.success : ZevTheme.Colors.warning
                        ) {
                            handleSelectGame(ffmaxGame, isInstalled: ffmaxInstalled)
                        }
                    }
                    
                    // MARK: - Bottom Refresh & Support
                    HStack(spacing: 12) {
                        Button(action: refreshInstallStatus) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.clockwise")
                                    .rotationEffect(.degrees(isChecking ? 360 : 0))
                                    .animation(isChecking ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isChecking)
                                Text("Kiểm tra lại cài đặt")
                                    .font(ZevTheme.Typography.caption(12))
                            }
                            .foregroundColor(ZevTheme.Colors.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(ZevTheme.Colors.surface2)
                            .cornerRadius(ZevTheme.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                    .stroke(ZevTheme.Colors.border, lineWidth: 1)
                            )
                        }
                        
                        Button(action: openZaloSupport) {
                            HStack(spacing: 6) {
                                Image(systemName: "headphones")
                                Text("Hỗ trợ Zalo")
                                    .font(ZevTheme.Typography.caption(12))
                            }
                            .foregroundColor(ZevTheme.Colors.textMuted)
                            .frame(maxWidth: .infinity)
                            .frame(height: 40)
                            .background(ZevTheme.Colors.surface2)
                            .cornerRadius(ZevTheme.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                    .stroke(ZevTheme.Colors.border, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            refreshInstallStatus()
        }
        .alert(isPresented: $showWarningAlert) {
            Alert(
                title: Text("Game Chưa Cài Đặt"),
                message: Text("Hệ thống phát hiện thiết bị chưa cài đặt phiên bản này. Bạn có muốn tiếp tục truy cập menu chức năng không?"),
                primaryButton: .default(Text("Vẫn Tiếp Tục")) {
                    if let g = pendingSelectedGame {
                        appState.selectGame(g)
                    }
                },
                secondaryButton: .cancel(Text("Quay Lại"))
            )
        }
    }
    
    // MARK: - Card Component
    
    private func gameCard(
        game: Game,
        isInstalled: Bool,
        badgeColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                // Main Content
                HStack(spacing: 14) {
                    // Logo Game
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(ZevTheme.Colors.surface2)
                            .frame(width: 64, height: 64)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(ZevTheme.Colors.border, lineWidth: 1)
                            )
                        
                        AsyncImage(url: URL(string: game.logoUrl ?? "")) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            default:
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(ZevTheme.Colors.warning)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.displayName)
                            .font(ZevTheme.Typography.title(16))
                            .foregroundColor(ZevTheme.Colors.text)
                        
                        Text(game.bundleId)
                            .font(ZevTheme.Typography.mono(12))
                            .foregroundColor(ZevTheme.Colors.primary)
                        
                        Text(game.description ?? "")
                            .font(ZevTheme.Typography.caption(11))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(ZevTheme.Colors.textDim)
                }
                .padding(16)
                
                Divider()
                    .background(ZevTheme.Colors.border.opacity(0.6))
                
                // Bottom Status Bar: "Sẵn sàng" hoặc "Chưa Cài Đặt"
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(badgeColor)
                            .frame(width: 8, height: 8)
                        
                        Text("Trạng thái thiết bị:")
                            .font(ZevTheme.Typography.caption(12))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 5) {
                        Image(systemName: isInstalled ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .font(.system(size: 12))
                        Text(isInstalled ? "Sẵn sàng" : "Chưa Cài Đặt")
                            .font(ZevTheme.Typography.caption(12))
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(badgeColor.opacity(0.15))
                    .foregroundColor(badgeColor)
                    .cornerRadius(ZevTheme.Radius.sm)
                    .overlay(
                        RoundedRectangle(cornerRadius: ZevTheme.Radius.sm)
                            .stroke(badgeColor.opacity(0.35), lineWidth: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ZevTheme.Colors.surface2.opacity(0.5))
            }
            .background(ZevTheme.Colors.surface)
            .cornerRadius(ZevTheme.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: ZevTheme.Radius.lg)
                    .stroke(ZevTheme.Colors.border, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    
    private func refreshInstallStatus() {
        isChecking = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let thStatus = GameDetectionService.shared.checkInstallation(bundleId: ffthGame.bundleId).isInstalled
            let maxStatus = GameDetectionService.shared.checkInstallation(bundleId: ffmaxGame.bundleId).isInstalled
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation {
                    self.ffthInstalled = thStatus
                    self.ffmaxInstalled = maxStatus
                    self.isChecking = false
                }
            }
        }
    }
    
    private func handleSelectGame(_ game: Game, isInstalled: Bool) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if isInstalled {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                appState.selectGame(game)
            }
        } else {
            pendingSelectedGame = game
            showWarningAlert = true
        }
    }
    
    private func openZaloSupport() {
        if let url = URL(string: "https://zalo.me/0365829172") {
            UIApplication.shared.open(url)
        }
    }
}
