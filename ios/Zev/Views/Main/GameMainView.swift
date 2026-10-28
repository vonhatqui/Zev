import SwiftUI

// MARK: - GameMainView
// Giao diện chính của game đã chọn: Khung Thiết Bị | Phiên Bản | Có hỗ trợ, cùng các danh mục menu chức năng

struct GameMainView: View {
    @EnvironmentObject var appState: AppStateManager
    
    @State private var categories: [FeatureCategory] = []
    @State private var features: [Feature] = []
    @State private var isLoading: Bool = false
    @State private var selectedCategory: FeatureCategory? = nil
    
    // Alert & Modal states
    @State private var showUnsupportedAlert: Bool = false
    @State private var unsupportedFeatureTitle: String = ""
    
    // Áp dụng Patch state
    @State private var activePatchingFeature: Feature? = nil
    @State private var isPatching: Bool = false
    @State private var patchProgress: Double = 0.0
    @State private var patchStatusText: String = ""
    @State private var showPatchSuccess: Bool = false
    @State private var patchErrorMessage: String? = nil
    
    // Preview Image Modal (Modskin)
    @State private var previewImageURL: String? = nil
    
    private let deviceService = DeviceService.shared
    private let patchService = GamePatchService.shared
    
    var body: some View {
        ZStack {
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // Top Game Bar & Switch Game Button
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "flame.fill")
                            .foregroundColor(ZevTheme.Colors.warning)
                            .font(.system(size: 15))
                        
                        Text(appState.selectedGame?.displayName ?? "Free Fire")
                            .font(ZevTheme.Typography.heading(15))
                            .foregroundColor(ZevTheme.Colors.text)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        let gen = UIImpactFeedbackGenerator(style: .light)
                        gen.impactOccurred()
                        withAnimation {
                            appState.switchGame()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11))
                            Text("Đổi Game")
                                .font(ZevTheme.Typography.caption(12))
                        }
                        .foregroundColor(ZevTheme.Colors.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(ZevTheme.Colors.surface2)
                        .cornerRadius(ZevTheme.Radius.sm)
                        .overlay(
                            RoundedRectangle(cornerRadius: ZevTheme.Radius.sm)
                                .stroke(ZevTheme.Colors.border, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(ZevTheme.Colors.surface)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // MARK: - KHUNG TRÊN ĐẦU: Thiết Bị | Phiên Bản | Có hỗ trợ
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                
                                // Cột 1: Thiết Bị
                                VStack(spacing: 4) {
                                    Text("THIẾT BỊ")
                                        .font(ZevTheme.Typography.caption(10))
                                        .fontWeight(.bold)
                                        .foregroundColor(ZevTheme.Colors.textMuted)
                                    
                                    Text(deviceService.deviceCommercialName)
                                        .font(ZevTheme.Typography.heading(13))
                                        .foregroundColor(ZevTheme.Colors.text)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.8)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                
                                Divider()
                                    .frame(height: 38)
                                    .background(ZevTheme.Colors.border)
                                
                                // Cột 2: Phiên Bản
                                VStack(spacing: 4) {
                                    Text("PHIÊN BẢN")
                                        .font(ZevTheme.Typography.caption(10))
                                        .fontWeight(.bold)
                                        .foregroundColor(ZevTheme.Colors.textMuted)
                                    
                                    Text("iOS " + deviceService.iosVersion)
                                        .font(ZevTheme.Typography.mono(13))
                                        .foregroundColor(ZevTheme.Colors.text)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                
                                Divider()
                                    .frame(height: 38)
                                    .background(ZevTheme.Colors.border)
                                
                                // Cột 3: Trạng thái 3105-2.0
                                VStack(spacing: 4) {
                                    Text("TRẠNG THÁI")
                                        .font(ZevTheme.Typography.caption(10))
                                        .fontWeight(.bold)
                                        .foregroundColor(ZevTheme.Colors.textMuted)
                                    
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(SupportPolicy.isCurrentDeviceSupported ? ZevTheme.Colors.success : ZevTheme.Colors.danger)
                                            .frame(width: 7, height: 7)
                                        
                                        Text(SupportPolicy.currentSupportBadgeText)
                                            .font(ZevTheme.Typography.caption(12))
                                            .fontWeight(.bold)
                                            .foregroundColor(SupportPolicy.isCurrentDeviceSupported ? ZevTheme.Colors.success : ZevTheme.Colors.danger)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                            }
                        }
                        .background(ZevTheme.Colors.surface2)
                        .cornerRadius(ZevTheme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                .stroke(SupportPolicy.isCurrentDeviceSupported ? ZevTheme.Colors.primary.opacity(0.4) : ZevTheme.Colors.danger.opacity(0.4), lineWidth: 1.5)
                        )
                        .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 3)
                        .padding(.top, 14)
                        
                        // MARK: - DANH MỤC CHỨC NĂNG
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("DANH MỤC TÍNH NĂNG")
                                    .font(ZevTheme.Typography.caption(12))
                                    .fontWeight(.bold)
                                    .foregroundColor(ZevTheme.Colors.textMuted)
                                    .tracking(1)
                                
                                Spacer()
                                
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            
                            // Danh sách categories dạng Card List
                            VStack(spacing: 14) {
                                ForEach(categories) { cat in
                                    categorySection(cat)
                                }
                            }
                        }
                        .padding(.bottom, 36)
                    }
                    .padding(.horizontal, 16)
                }
            }
            
            // MARK: - Patching Progress Overlay
            if isPatching {
                Color.black.opacity(0.75)
                    .ignoresSafeArea()
                
                VStack(spacing: 18) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(ZevTheme.Colors.primary)
                    
                    Text("Đang nạp file vào game...")
                        .font(ZevTheme.Typography.heading(16))
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    Text(patchStatusText)
                        .font(ZevTheme.Typography.body(13))
                        .foregroundColor(ZevTheme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                    
                    ProgressView(value: patchProgress, total: 1.0)
                        .tint(ZevTheme.Colors.primary)
                        .frame(width: 220)
                }
                .padding(24)
                .background(ZevTheme.Colors.surface)
                .cornerRadius(ZevTheme.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: ZevTheme.Radius.lg)
                        .stroke(ZevTheme.Colors.primary.opacity(0.4), lineWidth: 1)
                )
                .padding(32)
            }
            
            // MARK: - Patch Success Overlay
            if showPatchSuccess {
                Color.black.opacity(0.7)
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 54))
                        .foregroundColor(ZevTheme.Colors.success)
                    
                    Text("Áp Dụng Thành Công!")
                        .font(ZevTheme.Typography.title(18))
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    Text("File bản vá đã được nạp chính xác vào thư mục game. Bạn có thể mở game và trải nghiệm.")
                        .font(ZevTheme.Typography.body(13))
                        .foregroundColor(ZevTheme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                    
                    Button("Xong") {
                        withAnimation {
                            showPatchSuccess = false
                        }
                    }
                    .font(ZevTheme.Typography.body(15))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(ZevTheme.Gradients.primary)
                    .cornerRadius(ZevTheme.Radius.md)
                }
                .padding(24)
                .background(ZevTheme.Colors.surface)
                .cornerRadius(ZevTheme.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: ZevTheme.Radius.lg)
                        .stroke(ZevTheme.Colors.success.opacity(0.4), lineWidth: 1)
                )
                .padding(32)
            }
            
            // MARK: - Modskin Preview Modal
            if let previewUrl = previewImageURL {
                Color.black.opacity(0.85)
                    .ignoresSafeArea()
                    .onTapGesture { previewImageURL = nil }
                
                VStack(spacing: 16) {
                    HStack {
                        Text("Xem Trước Skin")
                            .font(ZevTheme.Typography.heading(16))
                            .foregroundColor(.white)
                        Spacer()
                        Button("Đóng") {
                            previewImageURL = nil
                        }
                        .foregroundColor(ZevTheme.Colors.primary)
                    }
                    
                    AsyncImage(url: URL(string: previewUrl)) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 380)
                                .cornerRadius(12)
                        case .failure:
                            Text("Không tải được ảnh preview")
                                .foregroundColor(ZevTheme.Colors.textMuted)
                                .padding(40)
                        default:
                            ProgressView()
                                .padding(40)
                        }
                    }
                }
                .padding(20)
                .background(ZevTheme.Colors.surface)
                .cornerRadius(ZevTheme.Radius.lg)
                .padding(20)
            }
        }
        .onAppear {
            loadCategoriesAndFeatures()
        }
        .alert(isPresented: $showUnsupportedAlert) {
            Alert(
                title: Text("Chưa Hỗ Trợ"),
                message: Text("Chức năng '\(unsupportedFeatureTitle)' hiện chưa có file hỗ trợ trên máy chủ. Vui lòng quay lại sau."),
                dismissButton: .default(Text("Đã Hiểu"))
            )
        }
    }
    
    // MARK: - Category Section View
    
    private func categorySection(_ category: FeatureCategory) -> some View {
        let catFeatures = features.filter { $0.categoryId == category.id }
        
        return VStack(spacing: 0) {
            // Category Header Card
            HStack(spacing: 12) {
                // Logo danh mục (link catbox hoặc icon)
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ZevTheme.Colors.surface2)
                        .frame(width: 44, height: 44)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(ZevTheme.Colors.border, lineWidth: 1)
                        )
                    
                    if let logoUrl = category.logoUrl, !logoUrl.isEmpty {
                        AsyncImage(url: URL(string: logoUrl)) { phase in
                            switch phase {
                            case .success(let img):
                                img.resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            default:
                                defaultCategoryIcon(slug: category.slug)
                            }
                        }
                    } else {
                        defaultCategoryIcon(slug: category.slug)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .font(ZevTheme.Typography.heading(15))
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    Text(category.description ?? "Chức năng nạp bản vá")
                        .font(ZevTheme.Typography.caption(12))
                        .foregroundColor(ZevTheme.Colors.textMuted)
                }
                
                Spacer()
            }
            .padding(14)
            .background(ZevTheme.Colors.surface)
            
            Divider()
                .background(ZevTheme.Colors.border.opacity(0.7))
            
            // Sub-features List
            VStack(spacing: 0) {
                // Xử lý riêng cho Setup Antiban: hiển thị nút tải sing-box trên AppStore
                if category.slug.contains("antiban") || category.slug.contains("singbox") {
                    antibanSpecialRow()
                    Divider()
                        .background(ZevTheme.Colors.border.opacity(0.4))
                }
                
                if catFeatures.isEmpty {
                    HStack {
                        Text("Chưa có chức năng trong danh mục này")
                            .font(ZevTheme.Typography.caption(12))
                            .foregroundColor(ZevTheme.Colors.textDim)
                        Spacer()
                    }
                    .padding(14)
                } else {
                    ForEach(catFeatures) { feat in
                        featureRow(feat)
                        if feat.id != catFeatures.last?.id {
                            Divider()
                                .background(ZevTheme.Colors.border.opacity(0.4))
                        }
                    }
                }
            }
            .background(ZevTheme.Colors.surface2.opacity(0.4))
        }
        .cornerRadius(ZevTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                .stroke(ZevTheme.Colors.border, lineWidth: 1)
        )
    }
    
    // MARK: - Feature Row
    
    private func featureRow(_ feature: Feature) -> some View {
        Button(action: {
            handleFeatureTap(feature)
        }) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(feature.displayName)
                            .font(ZevTheme.Typography.body(14))
                            .fontWeight(.semibold)
                            .foregroundColor(ZevTheme.Colors.text)
                        
                        // Badge Chưa hỗ trợ nếu không có file
                        if !feature.hasFile {
                            Text("Chưa Hỗ Trợ")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ZevTheme.Colors.danger.opacity(0.18))
                                .foregroundColor(ZevTheme.Colors.danger)
                                .cornerRadius(4)
                        } else {
                            Text("Sẵn sàng")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(ZevTheme.Colors.success.opacity(0.18))
                                .foregroundColor(ZevTheme.Colors.success)
                                .cornerRadius(4)
                        }
                    }
                    
                    if let desc = feature.description, !desc.isEmpty {
                        Text(desc)
                            .font(ZevTheme.Typography.caption(11))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                    }
                }
                
                Spacer()
                
                // Nút Preview nếu có previewUrl (Modskin)
                if let prevUrl = feature.previewUrl, !prevUrl.isEmpty {
                    Button(action: {
                        previewImageURL = prevUrl
                    }) {
                        Text("Preview")
                            .font(ZevTheme.Typography.caption(11))
                            .fontWeight(.bold)
                            .foregroundColor(ZevTheme.Colors.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(ZevTheme.Colors.primary.opacity(0.15))
                            .cornerRadius(ZevTheme.Radius.sm)
                    }
                }
                
                // Nút Áp Dụng / Chưa Hỗ Trợ
                if feature.hasFile {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 11))
                        Text("Áp Dụng")
                            .font(ZevTheme.Typography.caption(12))
                            .fontWeight(.bold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ZevTheme.Gradients.primary)
                    .cornerRadius(ZevTheme.Radius.sm)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 11))
                        Text("Chưa Hỗ Trợ")
                            .font(ZevTheme.Typography.caption(12))
                    }
                    .foregroundColor(ZevTheme.Colors.textDim)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ZevTheme.Colors.surface2)
                    .cornerRadius(ZevTheme.Radius.sm)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Row đặc biệt cho Setup Antiban (tải sing-box AppStore)
    
    private func antibanSpecialRow() -> some View {
        HStack(spacing: 12) {
            Image(systemName: "network.badge.shield.half.filled")
                .foregroundColor(ZevTheme.Colors.info)
                .font(.system(size: 20))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Tải app sing-box trên App Store")
                    .font(ZevTheme.Typography.body(13))
                    .fontWeight(.semibold)
                    .foregroundColor(ZevTheme.Colors.text)
                Text("Yêu cầu cài đặt sing-box để kích hoạt Antiban proxy")
                    .font(ZevTheme.Typography.caption(11))
                    .foregroundColor(ZevTheme.Colors.textMuted)
            }
            
            Spacer()
            
            Button(action: {
                patchService.openSingboxOnAppStore()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.app.fill")
                        .font(.system(size: 11))
                    Text("Tải Ngay")
                        .font(ZevTheme.Typography.caption(12))
                        .fontWeight(.bold)
                }
                .foregroundColor(ZevTheme.Colors.info)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(ZevTheme.Colors.info.opacity(0.15))
                .cornerRadius(ZevTheme.Radius.sm)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
    
    // MARK: - Category Default Icons
    
    @ViewBuilder
    private func defaultCategoryIcon(slug: String) -> some View {
        if slug.contains("menu") {
            Image(systemName: "square.grid.2x2.fill")
                .font(.system(size: 20))
                .foregroundColor(ZevTheme.Colors.primary)
        } else if slug.contains("aim") {
            Image(systemName: "scope")
                .font(.system(size: 20))
                .foregroundColor(ZevTheme.Colors.danger)
        } else if slug.contains("modskin") {
            Image(systemName: "tshirt.fill")
                .font(.system(size: 20))
                .foregroundColor(ZevTheme.Colors.secondary)
        } else {
            Image(systemName: "shield.checkerboard")
                .font(.system(size: 20))
                .foregroundColor(ZevTheme.Colors.warning)
        }
    }
    
    // MARK: - Actions
    
    private func loadCategoriesAndFeatures() {
        guard let game = appState.selectedGame else { return }
        isLoading = true
        
        Task {
            do {
                let catRes = try await APIService.shared.fetchCategories(gameId: game.id)
                let featRes = try await APIService.shared.fetchFeatures(gameId: game.id)
                
                await MainActor.run {
                    self.categories = catRes.categories
                    self.features = featRes.features
                    self.isLoading = false
                }
            } catch {
                // Fallback nạp danh mục mặc định theo đúng thiết kế user
                await MainActor.run {
                    self.categories = defaultFallbackCategories(gameId: game.id)
                    self.features = defaultFallbackFeatures()
                    self.isLoading = false
                }
            }
        }
    }
    
    private func handleFeatureTap(_ feature: Feature) {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        if !feature.hasFile {
            // Không có file trên server -> Hiển thị "Chưa Hỗ Trợ"
            unsupportedFeatureTitle = feature.displayName
            showUnsupportedAlert = true
            return
        }
        
        // Có file -> Tiến hành nạp file vào game
        guard let game = appState.selectedGame else { return }
        
        activePatchingFeature = feature
        isPatching = true
        patchProgress = 0.1
        patchStatusText = "Đang khởi tạo nạp file..."
        
        Task {
            do {
                try await patchService.applyFeaturePatch(
                    game: game,
                    feature: feature
                ) { progress, status in
                    DispatchQueue.main.async {
                        self.patchProgress = progress
                        self.patchStatusText = status
                    }
                }
                
                await MainActor.run {
                    isPatching = false
                    showPatchSuccess = true
                    let noteGen = UINotificationFeedbackGenerator()
                    noteGen.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    isPatching = false
                    patchErrorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // Fallback categories theo đúng yêu cầu người dùng
    private func defaultFallbackCategories(gameId: Int) -> [FeatureCategory] {
        return [
            FeatureCategory(
                id: 1,
                slug: "menu-project",
                displayName: "Menu Project",
                logoUrl: "https://files.catbox.moe/wetz7r.png",
                description: "Menu hack và script tổng hợp",
                sortOrder: 1,
                featureCount: 2,
                readyCount: 0
            ),
            FeatureCategory(
                id: 2,
                slug: "aim-cache",
                displayName: "Aim Cache",
                logoUrl: "https://files.catbox.moe/z7c8o6.png",
                description: "Tối ưu ngắm và khóa mục tiêu",
                sortOrder: 2,
                featureCount: 3,
                readyCount: 0
            ),
            FeatureCategory(
                id: 3,
                slug: "modskin-ffth",
                displayName: "Modskin FFTH",
                logoUrl: "https://files.catbox.moe/dvyw27.png",
                description: "Mod trang phục và hiệu ứng nhân vật",
                sortOrder: 3,
                featureCount: 2,
                readyCount: 0
            ),
            FeatureCategory(
                id: 4,
                slug: "setup-antiban",
                displayName: "Setup Antiban",
                logoUrl: nil,
                description: "Cấu hình bảo vệ tài khoản qua sing-box",
                sortOrder: 4,
                featureCount: 1,
                readyCount: 0
            )
        ]
    }
    
    private func defaultFallbackFeatures() -> [Feature] {
        return [
            Feature(id: 1, slug: "menu-v1", displayName: "Menu V1", description: "Menu cơ bản", status: .unsupported, fileId: nil, fileName: nil, previewUrl: nil, categoryId: 1, categoryName: "Menu Project", fileVersion: nil, fileSize: nil, targetPath: "Documents/", checksumSha256: nil),
            Feature(id: 2, slug: "menu-cheatexternal", displayName: "Menu CheatExternal", description: "Menu Cheat External", status: .unsupported, fileId: nil, fileName: nil, previewUrl: nil, categoryId: 1, categoryName: "Menu Project", fileVersion: nil, fileSize: nil, targetPath: "Documents/", checksumSha256: nil),
            Feature(id: 3, slug: "aim-head", displayName: "Aim Head", description: "Khóa tâm đầu", status: .unsupported, fileId: nil, fileName: nil, previewUrl: nil, categoryId: 2, categoryName: "Aim Cache", fileVersion: nil, fileSize: nil, targetPath: "Documents/cached/", checksumSha256: nil),
            Feature(id: 4, slug: "aim-body", displayName: "Aim Body", description: "Khóa tâm thân", status: .unsupported, fileId: nil, fileName: nil, previewUrl: nil, categoryId: 2, categoryName: "Aim Cache", fileVersion: nil, fileSize: nil, targetPath: "Documents/cached/", checksumSha256: nil),
            Feature(id: 5, slug: "modskin-alock", displayName: "Modskin Alock (Preview)", description: "Trang phục Alock", status: .unsupported, fileId: nil, fileName: nil, previewUrl: "https://files.catbox.moe/dvyw27.png", categoryId: 3, categoryName: "Modskin FFTH", fileVersion: nil, fileSize: nil, targetPath: "Documents/", checksumSha256: nil),
            Feature(id: 6, slug: "modskin-katri", displayName: "Modskin Katri (Preview)", description: "Trang phục Katri", status: .unsupported, fileId: nil, fileName: nil, previewUrl: "https://files.catbox.moe/dvyw27.png", categoryId: 3, categoryName: "Modskin FFTH", fileVersion: nil, fileSize: nil, targetPath: "Documents/", checksumSha256: nil),
            Feature(id: 7, slug: "singbox-antiban", displayName: "Cấu hình Antiban sing-box", description: "File config proxy cho sing-box", status: .unsupported, fileId: nil, fileName: nil, previewUrl: nil, categoryId: 4, categoryName: "Setup Antiban", fileVersion: nil, fileSize: nil, targetPath: "sing-box", checksumSha256: nil)
        ]
    }
}
