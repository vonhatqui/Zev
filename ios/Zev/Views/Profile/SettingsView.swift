import SwiftUI

// MARK: - SettingsView
// Cài đặt ứng dụng: Cho phép thay đổi tên miền Server API trực tiếp mà không cần sửa code!

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    @State private var serverDomain: String = ""
    @State private var isTestingConnection: Bool = false
    @State private var connectionResult: String? = nil
    @State private var isSuccessResult: Bool = false
    @State private var showResetAlert: Bool = false
    @State private var cacheCleared: Bool = false
    
    var body: some View {
        ZStack {
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Nav Bar
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
                    
                    Text("Cài Đặt Hệ Thống")
                        .font(ZevTheme.Typography.heading(16))
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    Spacer()
                    
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
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // Section 1: Server Domain Config
                        serverDomainSection
                        
                        // Section 2: Cache Management
                        cacheSection
                        
                        // Section 3: App Information
                        appInfoSection
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            serverDomain = AppConfig.baseURL
        }
    }
    
    // MARK: - Server Domain Section
    private var serverDomainSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(
                title: "Cấu Hình Tên Miền Máy Chủ (API)",
                subtitle: "Tùy chỉnh domain máy chủ linh hoạt trong tương lai"
            )
            
            ZevCard(borderGlow: true) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("ĐỊA CHỈ MÁY CHỦ HIỆN TẠI")
                        .font(ZevTheme.Typography.caption(11))
                        .fontWeight(.bold)
                        .foregroundColor(ZevTheme.Colors.textMuted)
                    
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .foregroundColor(ZevTheme.Colors.primary)
                        
                        TextField("https://crackbomaydihihi.sbs", text: $serverDomain)
                            .font(ZevTheme.Typography.mono(14))
                            .foregroundColor(ZevTheme.Colors.text)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(12)
                    .background(ZevTheme.Colors.surface2)
                    .cornerRadius(ZevTheme.Radius.md)
                    .overlay(
                        RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                            .stroke(ZevTheme.Colors.border, lineWidth: 1)
                    )
                    
                    // Connection Result
                    if let result = connectionResult {
                        HStack(spacing: 8) {
                            Image(systemName: isSuccessResult ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(isSuccessResult ? ZevTheme.Colors.success : ZevTheme.Colors.danger)
                            
                            Text(result)
                                .font(ZevTheme.Typography.caption(12))
                                .foregroundColor(isSuccessResult ? ZevTheme.Colors.success : ZevTheme.Colors.danger)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background((isSuccessResult ? ZevTheme.Colors.success : ZevTheme.Colors.danger).opacity(0.12))
                        .cornerRadius(ZevTheme.Radius.sm)
                    }
                    
                    // Buttons
                    HStack(spacing: 10) {
                        // Test & Save Button
                        ZevButton(title: "Lưu & Kiểm Tra", icon: "network", style: .primary, isLoading: isTestingConnection) {
                            saveAndTestDomain()
                        }
                        
                        // Reset Button
                        Button(action: { showResetAlert = true }) {
                            Text("Mặc định")
                                .font(ZevTheme.Typography.caption(13))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                                .frame(height: 50)
                                .padding(.horizontal, 14)
                                .background(ZevTheme.Colors.surface2)
                                .cornerRadius(ZevTheme.Radius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                        .stroke(ZevTheme.Colors.border, lineWidth: 1)
                                )
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showResetAlert) {
            Alert(
                title: Text("Khôi phục tên miền gốc?"),
                message: Text("Địa chỉ máy chủ sẽ được đặt lại về: \(AppConfig.defaultBaseURL)"),
                primaryButton: .default(Text("Đặt lại")) {
                    AppConfig.resetBaseURL()
                    serverDomain = AppConfig.defaultBaseURL
                    connectionResult = "Đã đặt lại về domain mặc định."
                    isSuccessResult = true
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
    }
    
    // MARK: - Cache Section
    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Bộ Nhớ & Dữ Liệu Tạm")
            
            ZevCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Xóa bộ nhớ đệm (Cache)")
                            .font(ZevTheme.Typography.heading(14))
                            .foregroundColor(ZevTheme.Colors.text)
                        
                        Text("Xóa cấu hình app đã lưu và làm mới danh sách game")
                            .font(ZevTheme.Typography.caption(12))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                    }
                    
                    Spacer()
                    
                    Button(action: clearCache) {
                        Text(cacheCleared ? "Đã dọn dẹp" : "Dọn dẹp")
                            .font(ZevTheme.Typography.caption(12))
                            .fontWeight(.semibold)
                            .foregroundColor(cacheCleared ? ZevTheme.Colors.success : ZevTheme.Colors.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(ZevTheme.Colors.surface2)
                            .cornerRadius(ZevTheme.Radius.md)
                            .overlay(
                                RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                    .stroke(cacheCleared ? ZevTheme.Colors.success : ZevTheme.Colors.border, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - App Info Section
    private var appInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Thông Tin Ứng Dụng")
            
            ZevCard {
                VStack(spacing: 12) {
                    HStack(spacing: 14) {
                        AsyncImage(url: URL(string: AppConfig.appLogoURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            default:
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(ZevTheme.Colors.primary)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Zev iOS Client")
                                .font(ZevTheme.Typography.heading(15))
                                .foregroundColor(ZevTheme.Colors.text)
                            
                            Text("Phiên bản v\(AppConfig.appVersion) (Build \(AppConfig.buildNumber))")
                                .font(ZevTheme.Typography.caption(12))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                        }
                        
                        Spacer()
                    }
                    
                    Divider().background(ZevTheme.Colors.border)
                    
                    HStack {
                        Text("Phát triển bởi:")
                            .font(ZevTheme.Typography.caption(12))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        Spacer()
                        Text("Zev Security Team")
                            .font(ZevTheme.Typography.caption(12))
                            .foregroundColor(ZevTheme.Colors.text)
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    private func saveAndTestDomain() {
        var cleanURL = serverDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanURL.hasSuffix("/") {
            cleanURL.removeLast()
        }
        
        guard let url = URL(string: cleanURL), url.scheme != nil else {
            connectionResult = "Định dạng URL không hợp lệ (cần có http:// hoặc https://)"
            isSuccessResult = false
            return
        }
        
        AppConfig.baseURL = cleanURL
        isTestingConnection = true
        connectionResult = nil
        
        Task {
            do {
                _ = try await APIService.shared.fetchAppConfig()
                await MainActor.run {
                    connectionResult = "Kết nối máy chủ thành công!"
                    isSuccessResult = true
                    isTestingConnection = false
                }
            } catch {
                await MainActor.run {
                    connectionResult = "Đã lưu domain, nhưng chưa kết nối được: \(error.localizedDescription)"
                    isSuccessResult = false
                    isTestingConnection = false
                }
            }
        }
    }
    
    private func clearCache() {
        UserDefaults.standard.removeObject(forKey: AppConfig.UserDefaultsKeys.cachedAppConfig)
        UserDefaults.standard.removeObject(forKey: AppConfig.UserDefaultsKeys.lastConfigFetch)
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        cacheCleared = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            cacheCleared = false
        }
    }
}
