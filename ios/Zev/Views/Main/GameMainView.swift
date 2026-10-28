import SwiftUI

// MARK: - GameMainView
// Giao diện chính của game: Khung Thiết Bị | Phiên Bản | Có hỗ trợ
// Nút Loader ngang to vừa trên dashboard:
// 1. Chạm Loader -> chờ 2-5s tải file từ server về
// 2. Tải xong -> hiện nút Injector (icon ống tiêm syringe.fill) nạp vào Documents/
// 3. Nạp xong -> hiện nút X Uninjector (màu đỏ xmark.circle.fill) xoá sạch không còn dấu vết

enum PatchActionState {
    case idle
    case loadingServer
    case readyToInject(ActiveGamePatch)
    case injecting(Double, String)
    case injected(String)
    case uninjecting
}

struct GameMainView: View {
    @EnvironmentObject var appState: AppStateManager
    
    @State private var categories: [FeatureCategory] = []
    @State private var features: [Feature] = []
    @State private var isLoading: Bool = false
    @State private var selectedCategory: FeatureCategory? = nil
    
    // Patch Action State (Loader -> Injector -> Uninjector)
    @State private var patchActionState: PatchActionState = .idle
    @State private var noPatchAlert: Bool = false
    @State private var showUninjectSuccess: Bool = false
    @State private var uninjectSuccessText: String = ""
    
    // Alert & Modal states
    @State private var showUnsupportedAlert: Bool = false
    @State private var unsupportedFeatureTitle: String = ""
    
    // Legacy single feature patch state
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
                topBarView
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 18) {
                        
                        // MARK: - KHUNG TRÊN ĐẦU: Thiết Bị | Phiên Bản | Trạng Thái
                        deviceInfoBar
                            .padding(.top, 14)
                        
                        // MARK: - KHUNG LOADER / INJECTOR / UNINJECTOR (Dashboard Action Panel)
                        patchActionPanel
                        
                        // MARK: - DANH MỤC CHỨC NĂNG (Nút chọn danh mục)
                        categoriesSection
                            .padding(.bottom, 36)
                    }
                    .padding(.horizontal, 16)
                }
                .refreshable {
                    refreshAllData()
                }
            }
            
            // MARK: - Overlays & Modals
            modalsOverlay
        }
        .onAppear {
            checkCurrentInjectionStatus()
            loadCategoriesAndFeatures()
        }
        .onChange(of: appState.selectedGame?.bundleId) { _ in
            checkCurrentInjectionStatus()
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
    
    // MARK: - Top Bar
    
    private var topBarView: some View {
        HStack {
            HStack(spacing: 8) {
                if let logo = appState.selectedGame?.logoUrl, let url = URL(string: logo) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            img.resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 22, height: 22)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        default:
                            Image(systemName: "flame.fill")
                                .foregroundColor(ZevTheme.Colors.warning)
                                .font(.system(size: 15))
                        }
                    }
                } else {
                    Image(systemName: "flame.fill")
                        .foregroundColor(ZevTheme.Colors.warning)
                        .font(.system(size: 15))
                }
                
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
    }
    
    // MARK: - Device Info Bar
    
    private var deviceInfoBar: some View {
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
        .background(ZevTheme.Colors.surface)
        .cornerRadius(ZevTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                .stroke(ZevTheme.Colors.border, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - DASHBOARD LOADER / INJECTOR / UNINJECTOR PANEL
    
    private var patchActionPanel: some View {
        VStack(spacing: 12) {
            
            // Header: Trạng thái hiện tại
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(actionHeaderColor)
                        .frame(width: 8, height: 8)
                    
                    Text(actionHeaderTitle)
                        .font(ZevTheme.Typography.caption(12))
                        .fontWeight(.bold)
                        .foregroundColor(actionHeaderColor)
                }
                
                Spacer()
                
                if case .injected = patchActionState {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                        Text("Documents/ OK")
                            .font(ZevTheme.Typography.caption(10))
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ZevTheme.Colors.success.opacity(0.15))
                    .foregroundColor(ZevTheme.Colors.success)
                    .cornerRadius(6)
                } else if case .readyToInject = patchActionState {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 10))
                        Text("Đã Tải Xong")
                            .font(ZevTheme.Typography.caption(10))
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(ZevTheme.Colors.primary.opacity(0.15))
                    .foregroundColor(ZevTheme.Colors.primary)
                    .cornerRadius(6)
                }
            }
            
            // Thông tin bản vá (nếu đã tải xong hoặc đã nạp)
            if case .readyToInject(let patch) = patchActionState {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "shippingbox.fill")
                            .foregroundColor(ZevTheme.Colors.primary)
                            .font(.system(size: 15))
                        
                        Text(patch.displayName)
                            .font(ZevTheme.Typography.heading(13))
                            .foregroundColor(ZevTheme.Colors.text)
                        
                        Spacer()
                        
                        Text(patch.formattedSize)
                            .font(ZevTheme.Typography.mono(11))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(ZevTheme.Colors.surface2)
                            .cornerRadius(4)
                            .foregroundColor(ZevTheme.Colors.textMuted)
                    }
                    
                    HStack(spacing: 6) {
                        // File chính
                        HStack(spacing: 3) {
                            Image(systemName: patch.is3105Package ? "lock.doc.fill" : "doc.fill")
                                .font(.system(size: 10))
                            Text(patch.fileName)
                                .font(ZevTheme.Typography.caption(11))
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(ZevTheme.Colors.surface2)
                        .cornerRadius(4)
                        .foregroundColor(ZevTheme.Colors.text)
                        
                        // File cấu hình đính kèm nếu có
                        if let configName = patch.configFileName ?? (patch.configFileId != nil ? "localconfig.json" : nil) {
                            HStack(spacing: 3) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 10))
                                Text("+\(configName)")
                                    .font(ZevTheme.Typography.caption(11))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(ZevTheme.Colors.warning.opacity(0.15))
                            .foregroundColor(ZevTheme.Colors.warning)
                            .cornerRadius(4)
                        }
                        
                        // Password indicator nếu có
                        if patch.filePassword != nil && !patch.filePassword!.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "key.fill")
                                    .font(.system(size: 10))
                                Text("Có pass")
                                    .font(ZevTheme.Typography.caption(11))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(ZevTheme.Colors.success.opacity(0.15))
                            .foregroundColor(ZevTheme.Colors.success)
                            .cornerRadius(4)
                        }
                    }
                }
                .padding(10)
                .background(ZevTheme.Colors.surface2.opacity(0.6))
                .cornerRadius(ZevTheme.Radius.sm)
            } else if case .injected(let patchTitle) = patchActionState {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 24))
                        .foregroundColor(ZevTheme.Colors.success)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(patchTitle)
                            .font(ZevTheme.Typography.heading(13))
                            .foregroundColor(ZevTheme.Colors.text)
                        Text("Bản vá đang hoạt động trong thư mục Documents của game.")
                            .font(ZevTheme.Typography.caption(11))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                    }
                    Spacer()
                }
                .padding(10)
                .background(ZevTheme.Colors.success.opacity(0.08))
                .cornerRadius(ZevTheme.Radius.sm)
            }
            
            // MARK: - NÚT NGANG TO VỪA VẶN TRÊN DASHBOARD (Loader -> Injector -> Uninjector)
            actionButtonView
        }
        .padding(14)
        .background(ZevTheme.Colors.surface)
        .cornerRadius(ZevTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                .stroke(actionBorderColor, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    // MARK: - Action Button View
    
    @ViewBuilder
    private var actionButtonView: some View {
        switch patchActionState {
        case .idle:
            // Nút 1: LOADER
            Button(action: handleLoaderTap) {
                HStack(spacing: 8) {
                    Image(systemName: "tray.and.arrow.down.fill")
                        .font(.system(size: 16, weight: .bold))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LOADER - TẢI BẢN VÁ")
                            .font(.system(size: 14, weight: .bold))
                        Text("Chạm để kiểm tra và tải bản vá từ máy chủ (2-5s)")
                            .font(.system(size: 10))
                            .opacity(0.85)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 16))
                        .opacity(0.8)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(ZevTheme.Gradients.primary)
                .cornerRadius(ZevTheme.Radius.md)
                .shadow(color: ZevTheme.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            
        case .loadingServer:
            // Đang chờ 2-5s load file từ server về
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.9)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ĐANG TẢI DỮ LIỆU TỪ MÁY CHỦ...")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Đang đồng bộ gói bản vá, vui lòng chờ (2-5s)...")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(ZevTheme.Colors.surface2)
            .cornerRadius(ZevTheme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                    .stroke(ZevTheme.Colors.primary.opacity(0.5), lineWidth: 1)
            )
            
        case .readyToInject(let patch):
            // Nút 2: INJECTOR (Icon ống tiêm syringe.fill)
            Button(action: {
                handleInjectorTap(patch)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 18, weight: .bold))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("INJECTOR - NẠP VÀO GAME")
                            .font(.system(size: 14, weight: .bold))
                        Text("Nạp trực tiếp vào thư mục Documents của game")
                            .font(.system(size: 10))
                            .opacity(0.85)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .opacity(0.8)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#06B6D4"), Color(hex: "#2563EB")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(ZevTheme.Radius.md)
                .shadow(color: Color(hex: "#06B6D4").opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            
        case .injecting(let progress, let status):
            // Đang nạp vào Documents
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(ZevTheme.Colors.primary)
                        .scaleEffect(0.8)
                    
                    Text(status)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    Spacer()
                    
                    Text("\(Int(progress * 100))%")
                        .font(ZevTheme.Typography.mono(11))
                        .foregroundColor(ZevTheme.Colors.primary)
                }
                
                ProgressView(value: progress, total: 1.0)
                    .tint(ZevTheme.Colors.primary)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(ZevTheme.Colors.surface2)
            .cornerRadius(ZevTheme.Radius.md)
            
        case .injected:
            // Nút 3: UNINJECTOR (Màu đỏ xmark.circle.fill xoá sạch không còn dấu vết)
            Button(action: handleUninjectorTap) {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("UNINJECTOR - GỠ BẢN VÁ")
                            .font(.system(size: 14, weight: .bold))
                        Text("Xóa sạch toàn bộ file vừa nạp không còn dấu vết")
                            .font(.system(size: 10))
                            .opacity(0.9)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "trash.fill")
                        .font(.system(size: 14))
                        .opacity(0.8)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#EF4444"), Color(hex: "#DC2626")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(ZevTheme.Radius.md)
                .shadow(color: Color(hex: "#EF4444").opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            
        case .uninjecting:
            // Đang dọn dẹp sạch sẽ
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.9)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ĐANG GỠ VÀ DỌN DẸP SẠCH SẼ...")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Đang xóa các file trong Documents và khôi phục file gốc...")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(hex: "#7F1D1D"))
            .cornerRadius(ZevTheme.Radius.md)
        }
    }
    
    // MARK: - Panel Headers & Colors
    
    private var actionHeaderTitle: String {
        switch patchActionState {
        case .idle:
            return "QUẢN LÝ BẢN VÁ (LOADER & INJECTOR)"
        case .loadingServer:
            return "ĐANG ĐỒNG BỘ VỚI MÁY CHỦ"
        case .readyToInject:
            return "BẢN VÁ ĐÃ SẴN SÀNG ĐỂ NẠP"
        case .injecting:
            return "ĐANG NẠP VÀO DOCUMENTS/"
        case .injected:
            return "BẢN VÁ ĐANG HOẠT ĐỘNG TRONG GAME"
        case .uninjecting:
            return "ĐANG GỠ BẢN VÁ KHỎI DOCUMENTS/"
        }
    }
    
    private var actionHeaderColor: Color {
        switch patchActionState {
        case .idle:
            return ZevTheme.Colors.textMuted
        case .loadingServer:
            return ZevTheme.Colors.primary
        case .readyToInject:
            return Color(hex: "#06B6D4")
        case .injecting:
            return ZevTheme.Colors.primary
        case .injected:
            return ZevTheme.Colors.success
        case .uninjecting:
            return Color(hex: "#EF4444")
        }
    }
    
    private var actionBorderColor: Color {
        switch patchActionState {
        case .injected:
            return ZevTheme.Colors.success.opacity(0.4)
        case .readyToInject:
            return Color(hex: "#06B6D4").opacity(0.4)
        default:
            return ZevTheme.Colors.border
        }
    }
    
    // MARK: - Categories Section
    
    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CHỌN DANH MỤC TÍNH NĂNG")
                    .font(ZevTheme.Typography.caption(11))
                    .fontWeight(.bold)
                    .foregroundColor(ZevTheme.Colors.textMuted)
                    .tracking(1)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            
            // Các nút chọn danh mục
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(categories) { cat in
                        let isSelected = (selectedCategory?.id == cat.id) || (selectedCategory == nil && cat.id == categories.first?.id)
                        Button(action: {
                            let gen = UIImpactFeedbackGenerator(style: .light)
                            gen.impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedCategory = cat
                            }
                        }) {
                            HStack(spacing: 8) {
                                categoryThumbnail(cat)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cat.displayName)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .semibold))
                                        .foregroundColor(isSelected ? .white : ZevTheme.Colors.text)
                                    
                                    let count = features.filter { $0.categoryId == cat.id }.count
                                    Text("\(count) tính năng")
                                        .font(.system(size: 10))
                                        .foregroundColor(isSelected ? Color.white.opacity(0.85) : ZevTheme.Colors.textMuted)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                isSelected ?
                                AnyView(ZevTheme.Gradients.primary) :
                                AnyView(ZevTheme.Colors.surface)
                            )
                            .cornerRadius(ZevTheme.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                    .stroke(isSelected ? Color.clear : ZevTheme.Colors.border, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(isSelected ? 0.12 : 0.03), radius: isSelected ? 6 : 3, x: 0, y: 2)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(.vertical, 4)
            }
            
            // DANH SÁCH CHỨC NĂNG CỦA DANH MỤC ĐÃ CHỌN
            let activeCat = selectedCategory ?? categories.first
            if let cat = activeCat {
                selectedCategoryFeaturesView(category: cat)
            }
        }
    }
    
    // MARK: - Overlays & Modals
    
    @ViewBuilder
    private var modalsOverlay: some View {
        // Overlay lỗi nạp file
        if let err = patchErrorMessage {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(ZevTheme.Colors.danger)
                
                Text("Không Thể Nạp File")
                    .font(ZevTheme.Typography.title(16))
                    .foregroundColor(ZevTheme.Colors.text)
                
                Text(err)
                    .font(ZevTheme.Typography.body(13))
                    .foregroundColor(ZevTheme.Colors.textMuted)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                
                Button("Đã Hiểu") {
                    withAnimation {
                        patchErrorMessage = nil
                    }
                }
                .font(ZevTheme.Typography.body(14))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(ZevTheme.Colors.surface2)
                .cornerRadius(ZevTheme.Radius.md)
            }
            .padding(20)
            .background(ZevTheme.Colors.surface)
            .cornerRadius(ZevTheme.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: ZevTheme.Radius.lg)
                    .stroke(ZevTheme.Colors.danger.opacity(0.4), lineWidth: 1)
            )
            .padding(32)
        }
        
        // Overlay thành công sau khi nạp bản vá
        if showPatchSuccess {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(ZevTheme.Colors.success)
                
                Text("Áp Dụng Thành Công!")
                    .font(ZevTheme.Typography.title(17))
                    .foregroundColor(ZevTheme.Colors.text)
                
                Text("Bản vá đã được nạp trực tiếp vào thư mục Documents của game!\n\nLƯU Ý: Vui lòng vuốt tắt Free Fire khỏi đa nhiệm (đóng hẳn game) rồi mở lại để bản vá có hiệu lực.")
                    .font(ZevTheme.Typography.body(13))
                    .foregroundColor(ZevTheme.Colors.textMuted)
                    .multilineTextAlignment(.center)
                
                Button("Xong") {
                    withAnimation {
                        showPatchSuccess = false
                    }
                }
                .font(ZevTheme.Typography.body(14))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
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
        
        // Alert khi gỡ sạch bản vá thành công
        if showUninjectSuccess {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 52))
                    .foregroundColor(Color(hex: "#EF4444"))
                
                Text("Đã Gỡ Bản Vá!")
                    .font(ZevTheme.Typography.title(17))
                    .foregroundColor(ZevTheme.Colors.text)
                
                Text(uninjectSuccessText)
                    .font(ZevTheme.Typography.body(13))
                    .foregroundColor(ZevTheme.Colors.textMuted)
                    .multilineTextAlignment(.center)
                
                Button("Đã Xong") {
                    withAnimation {
                        showUninjectSuccess = false
                    }
                }
                .font(ZevTheme.Typography.body(14))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color(hex: "#EF4444"))
                .cornerRadius(ZevTheme.Radius.md)
            }
            .padding(24)
            .background(ZevTheme.Colors.surface)
            .cornerRadius(ZevTheme.Radius.lg)
            .padding(32)
        }
        
        // Alert khi không có bản vá nào được gán trên server
        if noPatchAlert {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "tray.fill")
                    .font(.system(size: 48))
                    .foregroundColor(ZevTheme.Colors.warning)
                
                Text("Chưa Có Bản Vá")
                    .font(ZevTheme.Typography.title(16))
                    .foregroundColor(ZevTheme.Colors.text)
                
                Text("Máy chủ hiện chưa tải lên bản vá nào cho tựa game này. Vui lòng liên hệ Admin hoặc thử lại sau.")
                    .font(ZevTheme.Typography.body(13))
                    .foregroundColor(ZevTheme.Colors.textMuted)
                    .multilineTextAlignment(.center)
                
                Button("Đóng") {
                    withAnimation {
                        noPatchAlert = false
                    }
                }
                .font(ZevTheme.Typography.body(14))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(ZevTheme.Colors.surface2)
                .cornerRadius(ZevTheme.Radius.md)
            }
            .padding(24)
            .background(ZevTheme.Colors.surface)
            .cornerRadius(ZevTheme.Radius.lg)
            .padding(32)
        }
        
        // Modskin preview modal
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
    
    // MARK: - Actions (Loader -> Injector -> Uninjector)
    
    private func checkCurrentInjectionStatus() {
        guard let game = appState.selectedGame else { return }
        if patchService.isInjected(bundleId: game.bundleId) {
            let record = patchService.getInjectionRecord(bundleId: game.bundleId)
            patchActionState = .injected(record?.patchTitle ?? "Bản vá đang hoạt động")
        } else {
            if case .injected = patchActionState {
                patchActionState = .idle
            }
        }
    }
    
    private func handleLoaderTap() {
        guard let game = appState.selectedGame else { return }
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        
        withAnimation {
            patchActionState = .loadingServer
        }
        
        Task {
            do {
                // Thời gian chờ 2-5s như yêu cầu người dùng
                let response = try await APIService.shared.fetchActivePatch(for: game.id)
                try await Task.sleep(nanoseconds: 2_500_000_000)
                
                await MainActor.run {
                    if response.hasPatch, let patch = response.patch {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.patchActionState = .readyToInject(patch)
                        }
                        let note = UINotificationFeedbackGenerator()
                        note.notificationOccurred(.success)
                    } else {
                        withAnimation {
                            self.patchActionState = .idle
                        }
                        self.noPatchAlert = true
                    }
                }
            } catch {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                await MainActor.run {
                    withAnimation {
                        self.patchActionState = .idle
                    }
                    self.patchErrorMessage = "Lỗi kết nối máy chủ: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func handleInjectorTap(_ patch: ActiveGamePatch) {
        guard let game = appState.selectedGame else { return }
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()
        
        withAnimation {
            patchActionState = .injecting(0.1, "Đang chuẩn bị...")
        }
        
        Task {
            do {
                try await patchService.applyActivePatch(game: game, patch: patch) { progress, status in
                    DispatchQueue.main.async {
                        self.patchActionState = .injecting(progress, status)
                    }
                }
                await MainActor.run {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        self.patchActionState = .injected(patch.displayName)
                    }
                    self.showPatchSuccess = true
                    let note = UINotificationFeedbackGenerator()
                    note.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        self.patchActionState = .readyToInject(patch)
                    }
                    self.patchErrorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func handleUninjectorTap() {
        guard let game = appState.selectedGame else { return }
        let gen = UIImpactFeedbackGenerator(style: .heavy)
        gen.impactOccurred()
        
        withAnimation {
            patchActionState = .uninjecting
        }
        
        Task {
            do {
                let count = try patchService.uninjectPatch(game: game)
                await MainActor.run {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        self.patchActionState = .idle
                    }
                    self.uninjectSuccessText = count > 0 ? "Đã xóa sạch \(count) file bản vá khỏi Documents không còn dấu vết!" : "Đã dọn dẹp sạch sẽ thư mục Documents không còn dấu vết!"
                    self.showUninjectSuccess = true
                    let note = UINotificationFeedbackGenerator()
                    note.notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        self.patchActionState = .injected("Bản vá đang hoạt động")
                    }
                    self.patchErrorMessage = "Lỗi khi gỡ bản vá: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func refreshAllData() {
        checkCurrentInjectionStatus()
        loadCategoriesAndFeatures()
    }
    
    // MARK: - Category View Helpers
    
    private func categoryThumbnail(_ cat: FeatureCategory) -> some View {
        Group {
            if let logo = cat.logoUrl, let url = URL(string: logo) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fit)
                    default:
                        Image(systemName: "folder.fill")
                            .foregroundColor(ZevTheme.Colors.primary)
                    }
                }
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "folder.fill")
                    .foregroundColor(ZevTheme.Colors.primary)
                    .frame(width: 22, height: 22)
            }
        }
    }
    
    private func selectedCategoryFeaturesView(category: FeatureCategory) -> some View {
        let catFeatures = features.filter { $0.categoryId == category.id }
        
        return VStack(spacing: 10) {
            if catFeatures.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(ZevTheme.Colors.textDim)
                    Text("Chưa có chức năng nào trong danh mục này")
                        .font(ZevTheme.Typography.caption(12))
                        .foregroundColor(ZevTheme.Colors.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .background(ZevTheme.Colors.surface)
                .cornerRadius(ZevTheme.Radius.md)
            } else {
                ForEach(catFeatures) { feat in
                    featureItemRow(feat)
                }
            }
        }
    }
    
    private func featureItemRow(_ feat: Feature) -> some View {
        HStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(feat.hasFile ? ZevTheme.Colors.primary.opacity(0.12) : ZevTheme.Colors.surface2)
                    .frame(width: 38, height: 38)
                
                Image(systemName: feat.hasFile ? "bolt.fill" : "lock.fill")
                    .font(.system(size: 14))
                    .foregroundColor(feat.hasFile ? ZevTheme.Colors.primary : ZevTheme.Colors.textDim)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(feat.displayName)
                    .font(ZevTheme.Typography.body(14))
                    .fontWeight(.semibold)
                    .foregroundColor(ZevTheme.Colors.text)
                
                if let desc = feat.description, !desc.isEmpty {
                    Text(desc)
                        .font(ZevTheme.Typography.caption(11))
                        .foregroundColor(ZevTheme.Colors.textMuted)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Preview button nếu có previewUrl
            if let preview = feat.previewUrl, !preview.isEmpty {
                Button(action: {
                    self.previewImageURL = preview
                }) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 13))
                        .foregroundColor(ZevTheme.Colors.primary)
                        .padding(8)
                        .background(ZevTheme.Colors.surface2)
                        .clipShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            // Badge trạng thái
            Text(feat.hasFile ? "Sẵn sàng" : "Chưa có file")
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(feat.hasFile ? ZevTheme.Colors.success.opacity(0.12) : ZevTheme.Colors.surface2)
                .foregroundColor(feat.hasFile ? ZevTheme.Colors.success : ZevTheme.Colors.textMuted)
                .cornerRadius(6)
        }
        .padding(12)
        .background(ZevTheme.Colors.surface)
        .cornerRadius(ZevTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                .stroke(ZevTheme.Colors.border, lineWidth: 1)
        )
    }
    
    private func loadCategoriesAndFeatures() {
        guard let game = appState.selectedGame else { return }
        isLoading = true
        
        Task {
            do {
                let catRes = try await APIService.shared.fetchCategories(for: game.id)
                let featList = try await APIService.shared.fetchFeatures(for: game.id)
                
                await MainActor.run {
                    self.categories = catRes.categories
                    self.features = featList
                    if self.selectedCategory == nil {
                        self.selectedCategory = self.categories.first
                    }
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.categories = defaultFallbackCategories(gameId: game.id)
                    self.features = defaultFallbackFeatures()
                    if self.selectedCategory == nil {
                        self.selectedCategory = self.categories.first
                    }
                    self.isLoading = false
                }
            }
        }
    }
    
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
