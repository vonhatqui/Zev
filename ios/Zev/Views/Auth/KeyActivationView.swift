import SwiftUI

// MARK: - KeyActivationView
// Màn hình Đăng nhập theo Key với thông tin thiết bị chuẩn xác và Modal Thành Công (Success)

struct KeyActivationView: View {
    @EnvironmentObject var appState: AppStateManager
    
    @State private var keyCode: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    
    // Modal thành công
    @State private var showSuccessModal: Bool = false
    @State private var activationResult: ActivationResult? = nil
    @State private var verifiedKey: String = ""
    
    private let deviceService = DeviceService.shared
    
    var body: some View {
        ZStack {
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            // Background Light Effects
            VStack {
                Circle()
                    .fill(ZevTheme.Colors.primary.opacity(0.14))
                    .blur(radius: 90)
                    .frame(width: 320, height: 320)
                    .offset(y: -80)
                Spacer()
            }
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // MARK: - Top App Logo & Branding
                    VStack(spacing: 14) {
                        // Logo sạch sẽ, loại bỏ hoàn toàn viền tím
                        AsyncImage(url: URL(string: AppConfig.appLogoURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 80, height: 80)
                                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                            default:
                                Image(systemName: "key.fill")
                                    .font(.system(size: 38))
                                    .foregroundColor(ZevTheme.Colors.primary)
                            }
                        }
                        
                        VStack(spacing: 6) {
                            HStack(spacing: 8) {
                                RainbowLEDText(text: "ZEV", fontSize: 28)
                                Text("LOGIN")
                                    .font(.system(size: 24, weight: .bold, design: .rounded))
                                    .foregroundColor(ZevTheme.Colors.text)
                                    .tracking(1.5)
                            }
                            
                            Text("Nhập mã key để đăng nhập và mở khóa tính năng")
                                .font(ZevTheme.Typography.body(13))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Maintenance Banner
                    if appState.maintenanceMode {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(ZevTheme.Colors.warning)
                                .font(.system(size: 18))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Hệ thống đang bảo trì")
                                    .font(ZevTheme.Typography.heading(14))
                                    .foregroundColor(ZevTheme.Colors.warning)
                                
                                Text(appState.maintenanceMessage.isEmpty ? "Vui lòng quay lại sau ít phút." : appState.maintenanceMessage)
                                    .font(ZevTheme.Typography.caption(12))
                                    .foregroundColor(ZevTheme.Colors.textMuted)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ZevTheme.Colors.warning.opacity(0.12))
                        .cornerRadius(ZevTheme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                .stroke(ZevTheme.Colors.warning.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // Error Banner
                    if let error = errorMessage {
                        HStack(spacing: 10) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ZevTheme.Colors.danger)
                            Text(error)
                                .font(ZevTheme.Typography.caption(13))
                                .foregroundColor(ZevTheme.Colors.danger)
                            Spacer()
                            Button(action: { errorMessage = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 12))
                                    .foregroundColor(ZevTheme.Colors.textMuted)
                            }
                        }
                        .padding(12)
                        .background(ZevTheme.Colors.danger.opacity(0.12))
                        .cornerRadius(ZevTheme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                .stroke(ZevTheme.Colors.danger.opacity(0.3), lineWidth: 1)
                        )
                    }
                    
                    // MARK: - Ô Nhập Key & Nút Kích Hoạt
                    ZevCard(borderGlow: true) {
                        VStack(spacing: 18) {
                            
                            // Input Header
                            HStack {
                                Text("MÃ BẢN QUYỀN (KEY)")
                                    .font(ZevTheme.Typography.caption(12))
                                    .fontWeight(.bold)
                                    .foregroundColor(ZevTheme.Colors.textMuted)
                                
                                Spacer()
                                
                                Button(action: pasteKey) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "doc.on.clipboard")
                                            .font(.system(size: 11))
                                        Text("Dán mã")
                                            .font(ZevTheme.Typography.caption(12))
                                    }
                                    .foregroundColor(ZevTheme.Colors.primary)
                                }
                            }
                            
                            // Input Box
                            HStack(spacing: 12) {
                                Image(systemName: "lock.shield")
                                    .font(.system(size: 18))
                                    .foregroundColor(ZevTheme.Colors.primary)
                                
                                TextField("ZEV-XXXX-XXXX-XXXX", text: $keyCode)
                                    .font(ZevTheme.Typography.mono(15))
                                    .foregroundColor(ZevTheme.Colors.text)
                                    .textInputAutocapitalization(.characters)
                                    .disableAutocorrection(true)
                                
                                if !keyCode.isEmpty {
                                    Button(action: { keyCode = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(ZevTheme.Colors.textDim)
                                            .font(.system(size: 16))
                                    }
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(ZevTheme.Colors.surface2)
                            .cornerRadius(ZevTheme.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                    .stroke(ZevTheme.Colors.border, lineWidth: 1)
                            )
                            
                            // Activate Button
                            ZevButton(
                                title: "Kích Hoạt Key",
                                icon: "bolt.fill",
                                style: .primary,
                                isLoading: isLoading
                            ) {
                                Task {
                                    await performActivation()
                                }
                            }
                        }
                    }
                    
                    // MARK: - Thông Tin Hỗ Trợ Thiết Bị (Ngay Dưới Ô Nhập Key)
                    ZevCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "iphone.smartbatterycase.gen1")
                                    .foregroundColor(ZevTheme.Colors.primary)
                                    .font(.system(size: 15))
                                
                                Text("Thông tin hỗ trợ thiết bị")
                                    .font(ZevTheme.Typography.heading(14))
                                    .foregroundColor(ZevTheme.Colors.text)
                                
                                Spacer()
                                
                                StatusBadge(
                                    title: SupportPolicy.currentSupportBadgeText,
                                    color: SupportPolicy.isCurrentDeviceSupported ? ZevTheme.Colors.success : ZevTheme.Colors.danger
                                )
                            }
                            
                            Divider()
                                .background(ZevTheme.Colors.border)
                            
                            VStack(spacing: 10) {
                                infoRow(title: "Điện thoại:", value: deviceService.deviceCommercialName)
                                infoRow(title: "Phiên bản iOS:", value: "iOS " + deviceService.iosVersion)
                                infoRow(title: "Mã máy (HWID):", value: String(deviceService.deviceIdentifier.prefix(18)) + "...")
                                infoRow(title: "Model Identifier:", value: deviceService.deviceModelIdentifier)
                            }
                            
                            HStack(spacing: 6) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                Text("Key sau khi kích hoạt sẽ được khóa cố định theo mã máy (HWID) này.")
                                    .font(ZevTheme.Typography.caption(11))
                            }
                            .foregroundColor(ZevTheme.Colors.textDim)
                        }
                    }
                    
                    // MARK: - Help & Contact Support
                    VStack(spacing: 12) {
                        Text("Chưa có mã key hoặc cần gia hạn?")
                            .font(ZevTheme.Typography.caption(13))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        
                        HStack(spacing: 12) {
                            Button(action: openZaloSupport) {
                                HStack(spacing: 6) {
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 13))
                                    Text("Hỗ trợ Zalo: 0365829172")
                                        .font(ZevTheme.Typography.caption(13))
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(ZevTheme.Colors.surface2)
                                .foregroundColor(ZevTheme.Colors.primary)
                                .cornerRadius(ZevTheme.Radius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                        .stroke(ZevTheme.Colors.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 36)
                }
                .padding(.horizontal, 20)
            }
            
            // MARK: - Success Modal Popup
            if showSuccessModal, let res = activationResult {
                Color.black.opacity(0.75)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                VStack(spacing: 20) {
                    // Success Icon
                    ZStack {
                        Circle()
                            .fill(ZevTheme.Colors.success.opacity(0.18))
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .stroke(ZevTheme.Colors.success, lineWidth: 2)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 38, weight: .bold))
                            .foregroundColor(ZevTheme.Colors.success)
                    }
                    .padding(.top, 10)
                    
                    VStack(spacing: 6) {
                        Text("Thành công")
                            .font(ZevTheme.Typography.title(22))
                            .foregroundColor(ZevTheme.Colors.success)
                        
                        Text("Success · Kích hoạt thành công!")
                            .font(ZevTheme.Typography.body(14))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                    }
                    
                    // Time Info Card
                    VStack(spacing: 8) {
                        HStack {
                            Text("Thời gian key:")
                                .font(ZevTheme.Typography.body(13))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                            Spacer()
                            Text(res.key.displayExpiry)
                                .font(ZevTheme.Typography.heading(14))
                                .foregroundColor(ZevTheme.Colors.text)
                        }
                        
                        HStack {
                            Text("Mã key:")
                                .font(ZevTheme.Typography.body(13))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                            Spacer()
                            Text(verifiedKey)
                                .font(ZevTheme.Typography.mono(13))
                                .foregroundColor(ZevTheme.Colors.primary)
                        }
                        
                        HStack {
                            Text("Thiết bị:")
                                .font(ZevTheme.Typography.body(13))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                            Spacer()
                            Text(deviceService.deviceCommercialName)
                                .font(ZevTheme.Typography.caption(12))
                                .foregroundColor(ZevTheme.Colors.text)
                        }
                    }
                    .padding(14)
                    .background(ZevTheme.Colors.surface2)
                    .cornerRadius(ZevTheme.Radius.md)
                    
                    // Confirm Button (Nút Xác nhận -> Nhảy vào Chọn Game)
                    Button(action: confirmAndProceedToGameSelection) {
                        Text("Xác nhận")
                            .font(ZevTheme.Typography.body(16))
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(ZevTheme.Gradients.primary)
                            .cornerRadius(ZevTheme.Radius.md)
                            .shadow(color: ZevTheme.Colors.primary.opacity(0.4), radius: 10, x: 0, y: 4)
                    }
                }
                .padding(24)
                .background(ZevTheme.Colors.surface)
                .cornerRadius(ZevTheme.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: ZevTheme.Radius.lg)
                        .stroke(ZevTheme.Colors.success.opacity(0.4), lineWidth: 1.5)
                )
                .padding(.horizontal, 28)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Actions
    
    private func pasteKey() {
        if let clipboardString = UIPasteboard.general.string {
            keyCode = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
    }
    
    private func performActivation() async {
        let cleanKey = keyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanKey.isEmpty else {
            errorMessage = "Vui lòng nhập mã kích hoạt (key)."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await APIService.shared.verifyKey(cleanKey)
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            self.verifiedKey = cleanKey
            self.activationResult = result
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showSuccessModal = true
            }
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        } catch {
            errorMessage = "Không thể kết nối đến máy chủ key. Vui lòng kiểm tra mạng."
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        isLoading = false
    }
    
    private func confirmAndProceedToGameSelection() {
        guard let res = activationResult else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            showSuccessModal = false
            appState.activateKey(verifiedKey, result: res)
            // appState.activateKey đặt isActivated = true, RootView sẽ chuyển vào GameSelectionView vì selectedGame == nil!
        }
    }
    
    private func openZaloSupport() {
        if let url = URL(string: "https://zalo.me/0365829172") {
            UIApplication.shared.open(url)
        }
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(ZevTheme.Typography.caption(12))
                .foregroundColor(ZevTheme.Colors.textMuted)
            Spacer()
            Text(value)
                .font(ZevTheme.Typography.mono(12))
                .foregroundColor(ZevTheme.Colors.text)
        }
    }
}
