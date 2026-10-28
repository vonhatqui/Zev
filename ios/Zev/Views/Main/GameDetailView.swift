import SwiftUI

// MARK: - GameDetailView
// Chi tiết game, phân loại danh mục tính năng và trạng thái kích hoạt

struct GameDetailView: View {
    let game: Game
    
    @Environment(\.presentationMode) var presentationMode
    @State private var categories: [FeatureCategory] = []
    @State private var features: [Feature] = []
    @State private var selectedCategoryId: Int? = nil // nil = All
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var toggledFeatures: Set<Int> = []
    @State private var showInjectSuccessToast: Bool = false
    
    var filteredFeatures: [Feature] {
        if let catId = selectedCategoryId {
            return features.filter { $0.categoryId == catId }
        }
        return features
    }
    
    var body: some View {
        ZStack {
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                customNavBar
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ZevTheme.Colors.primary))
                        .scaleEffect(1.2)
                    Spacer()
                } else if let error = errorMessage {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundColor(ZevTheme.Colors.warning)
                        Text(error)
                            .font(ZevTheme.Typography.body(14))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        ZevButton(title: "Thử lại", style: .secondary, isFullWidth: false) {
                            Task { await loadData() }
                        }
                    }
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 20) {
                            // Game Hero Card
                            gameHeroCard
                            
                            // Category Filter Scroll
                            if !categories.isEmpty {
                                categoryFilterBar
                            }
                            
                            // Features Section
                            featuresSection
                            
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)
                    }
                }
            }
            
            // Toast Notification
            if showInjectSuccessToast {
                VStack {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(ZevTheme.Colors.success)
                        Text("Đã áp dụng cấu hình thành công!")
                            .font(ZevTheme.Typography.caption(13))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#1E202C"))
                    .cornerRadius(ZevTheme.Radius.full)
                    .overlay(
                        RoundedRectangle(cornerRadius: ZevTheme.Radius.full)
                            .stroke(ZevTheme.Colors.success.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 10, y: 5)
                    .padding(.top, 50)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(), value: showInjectSuccessToast)
            }
        }
        .navigationBarHidden(true)
        .task {
            await loadData()
        }
    }
    
    // MARK: - Custom Nav Bar
    private var customNavBar: some View {
        HStack {
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Quay lại")
                        .font(ZevTheme.Typography.body(15))
                }
                .foregroundColor(ZevTheme.Colors.primary)
            }
            
            Spacer()
            
            Text(game.shortName)
                .font(ZevTheme.Typography.heading(16))
                .foregroundColor(ZevTheme.Colors.text)
            
            Spacer()
            
            // Placeholder to balance navigation bar
            Color.clear.frame(width: 60, height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(ZevTheme.Colors.surface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(ZevTheme.Colors.border),
            alignment: .bottom
        )
    }
    
    // MARK: - Game Hero Card
    private var gameHeroCard: some View {
        ZevCard(borderGlow: true) {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    AsyncImage(url: URL(string: game.logoUrl ?? "")) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 64, height: 64)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        default:
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(ZevTheme.Colors.surface3)
                                    .frame(width: 64, height: 64)
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(ZevTheme.Colors.primary)
                            }
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(game.displayName)
                            .font(ZevTheme.Typography.title(18))
                            .foregroundColor(ZevTheme.Colors.text)
                        
                        Text(game.bundleId)
                            .font(ZevTheme.Typography.mono(11))
                            .foregroundColor(ZevTheme.Colors.textDim)
                        
                        HStack(spacing: 8) {
                            StatusBadge(title: "\(features.count) Tính năng", color: ZevTheme.Colors.primary)
                            StatusBadge(title: "Bản quyền OK", color: ZevTheme.Colors.success)
                        }
                        .padding(.top, 2)
                    }
                    
                    Spacer()
                }
                
                Divider().background(ZevTheme.Colors.border)
                
                // Fast Inject Button
                ZevButton(title: "Nạp Cấu Hình (Inject All)", icon: "bolt.badge.checkmark.fill", style: .primary) {
                    applyConfiguration()
                }
            }
        }
    }
    
    // MARK: - Category Filter Bar
    private var categoryFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // All Chip
                categoryChip(title: "Tất cả (\(features.count))", isSelected: selectedCategoryId == nil) {
                    selectedCategoryId = nil
                }
                
                // Each Category
                ForEach(categories) { cat in
                    categoryChip(title: cat.displayName, isSelected: selectedCategoryId == cat.id) {
                        selectedCategoryId = cat.id
                    }
                }
            }
            .padding(.horizontal, 2)
        }
    }
    
    private func categoryChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ZevTheme.Typography.caption(12))
                .fontWeight(isSelected ? .bold : .medium)
                .foregroundColor(isSelected ? .white : ZevTheme.Colors.textMuted)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? ZevTheme.Colors.primary : ZevTheme.Colors.surface2)
                .cornerRadius(ZevTheme.Radius.full)
                .overlay(
                    RoundedRectangle(cornerRadius: ZevTheme.Radius.full)
                        .stroke(isSelected ? ZevTheme.Colors.primary : ZevTheme.Colors.border, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Features Section
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Danh Sách Tính Năng",
                subtitle: "\(filteredFeatures.count) tuỳ chọn khả dụng"
            )
            
            if filteredFeatures.isEmpty {
                ZevCard {
                    HStack {
                        Spacer()
                        Text("Không có tính năng nào trong danh mục này.")
                            .font(ZevTheme.Typography.caption(13))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        Spacer()
                    }
                    .padding(.vertical, 16)
                }
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(filteredFeatures) { feat in
                        featureRow(feat)
                    }
                }
            }
        }
    }
    
    private func featureRow(_ feat: Feature) -> some View {
        ZevCard(padding: 12) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(feat.displayName)
                            .font(ZevTheme.Typography.heading(14))
                            .foregroundColor(ZevTheme.Colors.text)
                        
                        statusBadgeForFeature(feat.status)
                    }
                    
                    if let desc = feat.description, !desc.isEmpty {
                        Text(desc)
                            .font(ZevTheme.Typography.caption(12))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                    }
                }
                
                Spacer()
                
                // Toggle Button
                if feat.status == .ready {
                    Toggle("", isOn: Binding(
                        get: { toggledFeatures.contains(feat.id) },
                        set: { isEnabled in
                            if isEnabled {
                                toggledFeatures.insert(feat.id)
                            } else {
                                toggledFeatures.remove(feat.id)
                            }
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                        }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: ZevTheme.Colors.primary))
                }
            }
        }
    }
    
    @ViewBuilder
    private func statusBadgeForFeature(_ status: FeatureStatus) -> some View {
        switch status {
        case .ready:
            StatusBadge(title: status.displayText, color: ZevTheme.Colors.success)
        case .loading:
            StatusBadge(title: status.displayText, color: ZevTheme.Colors.warning)
        case .unsupported, .noFile, .incompatible:
            StatusBadge(title: status.displayText, color: ZevTheme.Colors.danger)
        case .error:
            StatusBadge(title: status.displayText, color: ZevTheme.Colors.textDim)
        }
    }
    
    // MARK: - Actions
    private func loadData() async {
        isLoading = true
        errorMessage = nil
        do {
            async let categoriesTask = APIService.shared.fetchCategories(for: game.id)
            async let featuresTask   = APIService.shared.fetchFeatures(for: game.id)
            
            let (catResp, featList) = try await (categoriesTask, featuresTask)
            categories = catResp.categories
            features = featList
            
            // Default: enable all ready features
            for f in featList where f.status == .ready {
                toggledFeatures.insert(f.id)
            }
        } catch {
            errorMessage = "Lỗi khi tải tính năng game: \(error.localizedDescription)"
        }
        isLoading = false
    }
    
    private func applyConfiguration() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        
        withAnimation {
            showInjectSuccessToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation {
                showInjectSuccessToast = false
            }
        }
    }
}
