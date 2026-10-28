import SwiftUI

// MARK: - GameMainView
// Giao diện chính của game:
// 1. Khung Trên: Top Game Bar + Đổi Game
// 2. Khung Thông Tin: Thiết Bị | Phiên Bản | Trạng Thái
// 3. Nút Điều Khiển Nằm Ở Vị Trí Khoanh Vùng (sát đáy, ngay trên TabBar):
//    - LOADER: Nút màu Vàng, chữ đen, icon arrow.down.circle.fill + "LOADER"
//    - INJECTOR (sau khi ấn loader xong): Nút màu Trắng, chữ đen, icon syringe.fill + "INJECTOR ( Phát hiện pacth. )"
//    - UNINJETOR (sau khi nạp xong): Nút màu Đỏ, chữ trắng, icon xmark.circle.fill + "UNINJETOR"
//    - Chuyển trạng thái mượt mà, toast tự tắt sau 3s, không popup khóa màn hình

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
                
                // Khung Thiết Bị | Phiên Bản | Trạng Thái
                deviceInfoBar
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                
                Spacer()
                
                // Nút điều khiển đặt ngay vị trí người dùng khoanh vùng (sát đáy, trên TabBar)
                actionButtonView
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
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
    
    // MARK: - Main Action Button (Vị trí khoanh vùng sát đáy)
    
    @ViewBuilder
    private var actionButtonView: some View {
        switch patchActionState {
        case .idle:
            // Nút LOADER: Màu Vàng, chữ đen, icon arrow.down.circle.fill + "LOADER"
            Button(action: handleLoaderTap) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 19, weight: .bold))
                    Text("LOADER")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "#FACC15")) // Màu Vàng
                .cornerRadius(14)
                .shadow(color: Color(hex: "#FACC15").opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            
        case .loadingServer:
            // Đang tải từ server 2-5s
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.black)
                    .scaleEffect(0.9)
                Text("LOADER...")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(hex: "#FACC15").opacity(0.9))
            .cornerRadius(14)
            
        case .readyToInject(let patch):
            // Nút INJECTOR: Màu Trắng, chữ đen, icon syringe.fill + ( Phát hiện pacth. )
            Button(action: { handleInjectorTap(patch) }) {
                HStack(spacing: 8) {
                    Image(systemName: "syringe.fill")
                        .font(.system(size: 18, weight: .bold))
                        .rotationEffect(.degrees(-45))
                    Text("INJECTOR ( Phát hiện pacth. )")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(Color.black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white) // Màu Trắng
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color(hex: "#CBD5E1"), lineWidth: 1.5)
                )
                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            
        case .injecting(let progress, _):
            // Đang nạp vào Documents
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.black)
                    .scaleEffect(0.9)
                Text("INJECTOR ( \(Int(progress * 100))% )...")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color.black)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.white)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(hex: "#CBD5E1"), lineWidth: 1.5)
            )
            
        case .injected:
            // Nút UNINJETOR: Màu Đỏ, chữ trắng, icon xmark.circle.fill + "UNINJETOR"
            Button(action: handleUninjectorTap) {
                HStack(spacing: 10) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 19, weight: .bold))
                    Text("UNINJETOR")
                        .font(.system(size: 16, weight: .bold))
                        .tracking(0.5)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(hex: "#EF4444")) // Màu Đỏ
                .cornerRadius(14)
                .shadow(color: Color(hex: "#EF4444").opacity(0.4), radius: 8, x: 0, y: 3)
            }
            .buttonStyle(PlainButtonStyle())
            
        case .uninjecting:
            // Đang gỡ bỏ sạch sẽ
            HStack(spacing: 10) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(0.9)
                Text("UNINJETOR...")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(hex: "#DC2626"))
            .cornerRadius(14)
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
                // Thời gian chờ 2.5s như yêu cầu
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
        // Overlay thông báo lỗi nạp file
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
