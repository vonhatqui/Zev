import SwiftUI

// MARK: - KeyActivationView
// Màn hình kích hoạt bản quyền Key Zev với thiết kế hiện đại, kiểm tra thiết bị HWID

struct KeyActivationView: View {
    @EnvironmentObject var appState: AppStateManager
    
    @State private var keyCode: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    @State private var showSuccessAnimation: Bool = false
    
    private let deviceService = DeviceService.shared
    
    var body: some View {
        ZStack {
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            // Background Light Effects
            VStack {
                Circle()
                    .fill(ZevTheme.Colors.primary.opacity(0.12))
                    .blur(radius: 90)
                    .frame(width: 300, height: 300)
                    .offset(y: -80)
                Spacer()
            }
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    
                    // Top App Logo & Branding
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(ZevTheme.Colors.surface2)
                                .frame(width: 88, height: 88)
                                .overlay(
                                    Circle()
                                        .stroke(ZevTheme.Gradients.primary, lineWidth: 1.5)
                                )
                                .shadow(color: ZevTheme.Colors.primary.opacity(0.4), radius: 16, x: 0, y: 4)
                            
                            AsyncImage(url: URL(string: AppConfig.appLogoURL)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 58, height: 58)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                default:
                                    Image(systemName: "key.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(ZevTheme.Gradients.primary)
                                }
                            }
                        }
                        
                        VStack(spacing: 4) {
                            Text("ZEV ACTIVATION")
                                .font(ZevTheme.Typography.title(22))
                                .foregroundStyle(ZevTheme.Gradients.primary)
                                .tracking(1.5)
                            
                            Text("Kích hoạt bản quyền thiết bị để bắt đầu")
                                .font(ZevTheme.Typography.body(14))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                        }
                    }
                    .padding(.top, 24)
                    
                    // Maintenance Banner (nếu đang bảo trì)
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
                    
                    // Activation Card
                    ZevCard(borderGlow: true) {
                        VStack(spacing: 20) {
                            
                            // Input Header
                            HStack {
                                Text("MÃ BẢN QUYỀN (KEY)")
                                    .font(ZevTheme.Typography.caption(12))
                                    .fontWeight(.bold)
                                    .foregroundColor(ZevTheme.Colors.textMuted)
                                
                                Spacer()
                                
                                // Paste button
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
                                title: "Kích Hoạt Thiết Bị",
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
                    
                    // Device Binding Info Card
                    ZevCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(ZevTheme.Colors.info)
                                    .font(.system(size: 14))
                                
                                Text("Khóa liên kết thiết bị (HWID Lock)")
                                    .font(ZevTheme.Typography.heading(13))
                                    .foregroundColor(ZevTheme.Colors.text)
                                
                                Spacer()
                            }
                            
                            VStack(spacing: 8) {
                                infoRow(title: "Thiết bị:", value: deviceService.deviceCommercialName)
                                infoRow(title: "Hệ điều hành:", value: "iOS " + deviceService.iosVersion)
                                infoRow(title: "Mã định danh (HWID):", value: String(deviceService.deviceIdentifier.prefix(18)) + "...")
                                infoRow(title: "Phiên bản App:", value: "v" + AppConfig.appVersion)
                            }
                            
                            Text("⚠️ Key sau khi kích hoạt sẽ được liên kết cố định với thiết bị này để đảm bảo an toàn bản quyền.")
                                .font(ZevTheme.Typography.caption(11))
                                .foregroundColor(ZevTheme.Colors.textDim)
                                .lineSpacing(2)
                        }
                    }
                    
                    // Help & Purchase Links
                    VStack(spacing: 12) {
                        Text("Chưa có mã bản quyền hoặc cần trợ giúp?")
                            .font(ZevTheme.Typography.caption(13))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        
                        HStack(spacing: 12) {
                            Link(destination: URL(string: "https://t.me/zev_support")!) {
                                HStack(spacing: 6) {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 12))
                                    Text("Mua Key qua Telegram")
                                        .font(ZevTheme.Typography.caption(13))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
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
                    .padding(.bottom, 32)
                }
                .padding(.horizontal, 20)
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
            errorMessage = "Vui lòng nhập mã kích hoạt."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await APIService.shared.verifyKey(cleanKey)
            
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            withAnimation(.spring()) {
                appState.activateKey(cleanKey, result: result)
            }
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        } catch {
            errorMessage = "Không thể kết nối đến máy chủ. Vui lòng kiểm tra mạng."
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        isLoading = false
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
