import SwiftUI

// MARK: - GameMainView
// Giao diện chính của game: Khung Thiết Bị | Phiên Bản | Trạng Thái
// Sử dụng duy nhất Loader Dashboard theo yêu cầu người dùng:
// 1. Nút Loader ngang to vừa trên dashboard: Ấn chờ 2-5s tải file từ server về
// 2. Tải xong: Hiện nút Injector (icon ống tiêm syringe.fill) nạp vào Documents theo chuẩn 3105-2.0
// 3. Nạp xong: Chuyển thẳng sang nút Uninjector (màu đỏ xmark.circle.fill) xoá sạch không còn dấu vết
// 4. Không dùng popup chặn đứng màn hình, chuyển trạng thái mượt mà kèm thông báo toast tự tắt

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
    
    // Patch Action State (Loader -> Injector -> Uninjector)
    @State private var patchActionState: PatchActionState = .idle
    @State private var noPatchAlert: Bool = false
    @State private var patchErrorMessage: String? = nil
    
    // Floating Toast Notification
    @State private var toastMessage: String? = nil
    @State private var toastIsSuccess: Bool = true
    
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
                    VStack(spacing: 16) {
                        // MARK: - KHUNG TRÊN ĐẦU: Thiết Bị | Phiên Bản | Trạng Thái
                        deviceInfoBar
                            .padding(.top, 14)
                        
                        // MARK: - KHUNG LOADER / INJECTOR / UNINJECTOR (Dashboard Action Panel)
                        patchActionPanel
                            .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                }
                .refreshable {
                    checkCurrentInjectionStatus()
                }
            }
            
            // MARK: - Floating Toast Notification
            VStack {
                if let msg = toastMessage {
                    HStack(spacing: 10) {
                        Image(systemName: toastIsSuccess ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(toastIsSuccess ? ZevTheme.Colors.success : ZevTheme.Colors.danger)
                        
                        Text(msg)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#1E293B"))
                    .cornerRadius(ZevTheme.Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                            .stroke(toastIsSuccess ? ZevTheme.Colors.success.opacity(0.4) : ZevTheme.Colors.danger.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 4)
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture {
                        withAnimation { toastMessage = nil }
                    }
                }
                
                Spacer()
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: toastMessage)
            
            // MARK: - Modals (Chỉ mở khi có lỗi hoặc chưa có bản vá)
            modalsOverlay
        }
        .onAppear {
            checkCurrentInjectionStatus()
        }
        .onChange(of: appState.selectedGame?.bundleId) { _ in
            checkCurrentInjectionStatus()
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
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 11, weight: .bold))
                    Text("Đổi Game")
                        .font(ZevTheme.Typography.caption(12))
                        .fontWeight(.semibold)
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
        VStack(spacing: 14) {
            
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
                        Text("Documents/ 0777")
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
            
            // NÚT HÀNH ĐỘNG NGANG CHÍNH (LOADER / INJECTOR / UNINJECTOR)
            mainActionButton
            
            // THÔNG TIN BẢN VÁ CHI TIẾT
            if case .readyToInject(let patch) = patchActionState {
                readyPatchDetailsView(patch: patch)
            } else if case .injected(let patchTitle) = patchActionState {
                injectedPatchDetailsView(patchTitle: patchTitle)
            } else if case .idle = patchActionState {
                idleInstructionView
            }
        }
        .padding(16)
        .background(ZevTheme.Colors.surface)
        .cornerRadius(ZevTheme.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: ZevTheme.Radius.lg)
                .stroke(actionBorderColor, lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }
    
    // MARK: - Main Action Button
    
    @ViewBuilder
    private var mainActionButton: some View {
        switch patchActionState {
        case .idle:
            // Nút 1: LOADER (Tải file từ máy chủ)
            Button(action: handleLoaderTap) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LOADER - TẢI BẢN VÁ TỪ SERVER")
                            .font(.system(size: 13, weight: .bold))
                        Text("Tải cấu hình và bản vá mới nhất cho \(appState.selectedGame?.displayName ?? "game")")
                            .font(.system(size: 10))
                            .opacity(0.85)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "icloud.and.arrow.down.fill")
                        .font(.system(size: 15))
                        .opacity(0.8)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#06B6D4"), Color(hex: "#3B82F6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(ZevTheme.Radius.md)
                .shadow(color: Color(hex: "#06B6D4").opacity(0.35), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(PlainButtonStyle())
            
        case .loadingServer:
            // Đang tải từ server 2-5s
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.9)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ĐANG TÌM BẢN VÁ TỪ MÁY CHỦ...")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("Đang đồng bộ token và kiểm tra tính toàn vẹn...")
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [Color(hex: "#0284C7"), Color(hex: "#0369A1")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(ZevTheme.Radius.md)
            
        case .readyToInject(let patch):
            // Nút 2: INJECTOR (Icon ống tiêm syringe.fill)
            Button(action: { handleInjectorTap(patch) }) {
                HStack(spacing: 10) {
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 18, weight: .bold))
                        .rotationEffect(.degrees(-45))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("INJECTOR - NẠP VÀO GAME")
                            .font(.system(size: 13, weight: .bold))
                        Text("Áp dụng \(patch.displayName) chuẩn 3105 vào Documents/")
                            .font(.system(size: 10))
                            .opacity(0.9)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 16))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#10B981"), Color(hex: "#059669")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(ZevTheme.Radius.md)
                .shadow(color: Color(hex: "#10B981").opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            
        case .injecting(let progress, let status):
            // Đang nạp vào Documents
            VStack(spacing: 6) {
                HStack {
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
                            .font(.system(size: 13, weight: .bold))
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
    
    // MARK: - Subviews for Patch Information
    
    private func readyPatchDetailsView(patch: ActiveGamePatch) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(ZevTheme.Colors.primary)
                    .font(.system(size: 14))
                
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
                
                Spacer()
                
                // Nút tải lại
                Button(action: handleLoaderTap) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(ZevTheme.Colors.primary)
                }
            }
        }
        .padding(12)
        .background(ZevTheme.Colors.surface2.opacity(0.6))
        .cornerRadius(ZevTheme.Radius.md)
    }
    
    private func injectedPatchDetailsView(patchTitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(ZevTheme.Colors.success)
                    .font(.system(size: 16))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(patchTitle)
                        .font(ZevTheme.Typography.heading(13))
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    Text("Đã nạp thành công vào Documents/ (Quyền 0777 chuẩn 3105)")
                        .font(ZevTheme.Typography.caption(11))
                        .foregroundColor(ZevTheme.Colors.success)
                }
                
                Spacer()
            }
            
            Divider()
                .background(ZevTheme.Colors.border)
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 11))
                    .foregroundColor(ZevTheme.Colors.warning)
                
                Text("LƯU Ý: Vuốt tắt Free Fire khỏi đa nhiệm rồi mở lại để kích hoạt bản vá.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(ZevTheme.Colors.textMuted)
            }
        }
        .padding(12)
        .background(ZevTheme.Colors.success.opacity(0.08))
        .cornerRadius(ZevTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                .stroke(ZevTheme.Colors.success.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var idleInstructionView: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(ZevTheme.Colors.primary)
                .font(.system(size: 13))
            
            Text("Chạm vào nút LOADER ở trên để nạp bản vá trực tiếp vào game.")
                .font(ZevTheme.Typography.caption(11))
                .foregroundColor(ZevTheme.Colors.textMuted)
            
            Spacer()
        }
        .padding(10)
        .background(ZevTheme.Colors.surface2.opacity(0.5))
        .cornerRadius(ZevTheme.Radius.sm)
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
                // Thời gian chờ 2.5s đúng như yêu cầu
                let response = try await APIService.shared.fetchActivePatch(for: game.id)
                try await Task.sleep(nanoseconds: 2_500_000_000)
                
                await MainActor.run {
                    if response.hasPatch, let patch = response.patch {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            self.patchActionState = .readyToInject(patch)
                        }
                        showToast("Đã tải xong bản vá! Nhấn INJECTOR để nạp vào game.", isSuccess: true)
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
                try? await Task.sleep(nanoseconds: 1_500_000_000)
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
                    showToast("Áp dụng thành công! Vui lòng mở lại Free Fire để nhận bản vá.", isSuccess: true)
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
                    let msg = count > 0 ? "Đã gỡ sạch \(count) file bản vá khỏi Documents không còn dấu vết!" : "Đã dọn dẹp sạch sẽ Documents không còn dấu vết!"
                    showToast(msg, isSuccess: true)
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
    
    private func showToast(_ message: String, isSuccess: Bool = true) {
        withAnimation {
            toastMessage = message
            toastIsSuccess = isSuccess
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
    
    // MARK: - Modals (Lỗi & Chưa Có Bản Vá)
    
    @ViewBuilder
    private var modalsOverlay: some View {
        // Overlay lỗi nạp file
        if let err = patchErrorMessage {
            ZStack {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { patchErrorMessage = nil }
                    }
                
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(ZevTheme.Colors.danger)
                    
                    Text("Thông Báo Bản Vá")
                        .font(ZevTheme.Typography.title(16))
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    Text(err)
                        .font(ZevTheme.Typography.body(13))
                        .foregroundColor(ZevTheme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 10)
                    
                    Button(action: {
                        withAnimation { patchErrorMessage = nil }
                    }) {
                        Text("Đã Hiểu")
                            .font(ZevTheme.Typography.body(14))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(ZevTheme.Colors.primary)
                            .cornerRadius(ZevTheme.Radius.md)
                    }
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
            .transition(.opacity)
        }
        
        // Alert khi không có bản vá nào được gán trên server
        if noPatchAlert {
            ZStack {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation { noPatchAlert = false }
                    }
                
                VStack(spacing: 16) {
                    Image(systemName: "tray.fill")
                        .font(.system(size: 44))
                        .foregroundColor(ZevTheme.Colors.warning)
                    
                    Text("Chưa Có Bản Vá")
                        .font(ZevTheme.Typography.title(16))
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    Text("Máy chủ hiện chưa tải lên bản vá nào cho tựa game này. Vui lòng liên hệ Admin hoặc thử lại sau.")
                        .font(ZevTheme.Typography.body(13))
                        .foregroundColor(ZevTheme.Colors.textMuted)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        withAnimation { noPatchAlert = false }
                    }) {
                        Text("Đóng")
                            .font(ZevTheme.Typography.body(14))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 42)
                            .background(ZevTheme.Colors.surface2)
                            .cornerRadius(ZevTheme.Radius.md)
                    }
                }
                .padding(24)
                .background(ZevTheme.Colors.surface)
                .cornerRadius(ZevTheme.Radius.lg)
                .padding(32)
            }
            .transition(.opacity)
        }
    }
}
