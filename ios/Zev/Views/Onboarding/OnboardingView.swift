import SwiftUI
import UserNotifications

// MARK: - OnboardingView (Setup App)
// Màn hình thiết lập lần đầu: Cho phép thông báo, Chọn ngôn ngữ, Đồng ý điều khoản

struct OnboardingView: View {
    @EnvironmentObject var appState: AppStateManager
    
    @State private var notificationsAllowed: Bool = false
    @State private var selectedLanguage: String = "vi" // "vi" hoặc "en"
    @State private var isTermsAccepted: Bool = false
    @State private var showTermsSheet: Bool = false
    
    var body: some View {
        ZStack {
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            // Background ambient glow
            VStack {
                Circle()
                    .fill(ZevTheme.Colors.primary.opacity(0.16))
                    .blur(radius: 90)
                    .frame(width: 300, height: 300)
                    .offset(y: -100)
                Spacer()
            }
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // MARK: - Header
                    VStack(spacing: 12) {
                        // Logo tải tức thì
                        ZevCachedImage(
                            urlString: AppConfig.appLogoURL,
                            fallbackSystemIcon: "gearshape.2.fill",
                            width: 76,
                            height: 76,
                            cornerRadius: 18
                        )
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 3)
                        
                        VStack(spacing: 4) {
                            Text("THIẾT LẬP ỨNG DỤNG")
                                .font(ZevTheme.Typography.title(22))
                                .foregroundStyle(ZevTheme.Gradients.primary)
                                .tracking(1.2)
                            
                            Text("Cấu hình nhanh cho lần khởi chạy đầu tiên")
                                .font(ZevTheme.Typography.body(13))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                        }
                    }
                    .padding(.top, 20)
                    
                    // MARK: - Section 1: Cho phép Thông Báo
                    ZevCard(borderGlow: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(ZevTheme.Colors.primary.opacity(0.18))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "bell.badge.fill")
                                        .foregroundColor(ZevTheme.Colors.primary)
                                        .font(.system(size: 16))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Thông báo hệ thống")
                                        .font(ZevTheme.Typography.heading(15))
                                        .foregroundColor(ZevTheme.Colors.text)
                                    Text("Nhận cảnh báo khi có cập nhật file hoặc key sắp hết hạn")
                                        .font(ZevTheme.Typography.caption(12))
                                        .foregroundColor(ZevTheme.Colors.textMuted)
                                }
                            }
                            
                            Button(action: requestNotificationPermission) {
                                HStack {
                                    Image(systemName: notificationsAllowed ? "checkmark.circle.fill" : "bell.fill")
                                    Text(notificationsAllowed ? "Đã cho phép thông báo" : "Cho phép nhận thông báo")
                                        .fontWeight(.semibold)
                                }
                                .font(ZevTheme.Typography.body(13))
                                .foregroundColor(notificationsAllowed ? ZevTheme.Colors.success : ZevTheme.Colors.primary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 42)
                                .background(notificationsAllowed ? ZevTheme.Colors.success.opacity(0.12) : ZevTheme.Colors.surface2)
                                .cornerRadius(ZevTheme.Radius.md)
                                .overlay(
                                    RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                        .stroke(notificationsAllowed ? ZevTheme.Colors.success.opacity(0.4) : ZevTheme.Colors.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                    // MARK: - Section 2: Chọn Ngôn Ngữ
                    ZevCard(borderGlow: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(ZevTheme.Colors.info.opacity(0.18))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "globe")
                                        .foregroundColor(ZevTheme.Colors.info)
                                        .font(.system(size: 16))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Ngôn ngữ hiển thị")
                                        .font(ZevTheme.Typography.heading(15))
                                        .foregroundColor(ZevTheme.Colors.text)
                                    Text("Chọn ngôn ngữ ưa thích của bạn trong Zev")
                                        .font(ZevTheme.Typography.caption(12))
                                        .foregroundColor(ZevTheme.Colors.textMuted)
                                }
                            }
                            
                            HStack(spacing: 12) {
                                // Tiếng Việt
                                Button(action: {
                                    withAnimation(.spring()) {
                                        selectedLanguage = "vi"
                                        UserDefaults.standard.set("vi", forKey: AppConfig.UserDefaultsKeys.selectedLanguage)
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Text("🇻🇳")
                                            .font(.system(size: 20))
                                        Text("Tiếng Việt")
                                            .font(ZevTheme.Typography.body(14))
                                            .fontWeight(selectedLanguage == "vi" ? .bold : .medium)
                                        Spacer()
                                        if selectedLanguage == "vi" {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(ZevTheme.Colors.primary)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(selectedLanguage == "vi" ? ZevTheme.Colors.primary.opacity(0.15) : ZevTheme.Colors.surface2)
                                    .foregroundColor(selectedLanguage == "vi" ? ZevTheme.Colors.text : ZevTheme.Colors.textMuted)
                                    .cornerRadius(ZevTheme.Radius.md)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                            .stroke(selectedLanguage == "vi" ? ZevTheme.Colors.primary : ZevTheme.Colors.border, lineWidth: selectedLanguage == "vi" ? 1.5 : 1)
                                    )
                                }
                                
                                // English
                                Button(action: {
                                    withAnimation(.spring()) {
                                        selectedLanguage = "en"
                                        UserDefaults.standard.set("en", forKey: AppConfig.UserDefaultsKeys.selectedLanguage)
                                    }
                                }) {
                                    HStack(spacing: 8) {
                                        Text("🇬🇧")
                                            .font(.system(size: 20))
                                        Text("English")
                                            .font(ZevTheme.Typography.body(14))
                                            .fontWeight(selectedLanguage == "en" ? .bold : .medium)
                                        Spacer()
                                        if selectedLanguage == "en" {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(ZevTheme.Colors.primary)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 48)
                                    .background(selectedLanguage == "en" ? ZevTheme.Colors.primary.opacity(0.15) : ZevTheme.Colors.surface2)
                                    .foregroundColor(selectedLanguage == "en" ? ZevTheme.Colors.text : ZevTheme.Colors.textMuted)
                                    .cornerRadius(ZevTheme.Radius.md)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                            .stroke(selectedLanguage == "en" ? ZevTheme.Colors.primary : ZevTheme.Colors.border, lineWidth: selectedLanguage == "en" ? 1.5 : 1)
                                    )
                                }
                            }
                        }
                    }
                    
                    // MARK: - Section 3: Điều Khoản Sử Dụng
                    ZevCard(borderGlow: false) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle()
                                        .fill(ZevTheme.Colors.warning.opacity(0.18))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "checkmark.shield.fill")
                                        .foregroundColor(ZevTheme.Colors.warning)
                                        .font(.system(size: 16))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Điều khoản khi sử dụng")
                                        .font(ZevTheme.Typography.heading(15))
                                        .foregroundColor(ZevTheme.Colors.text)
                                    Text("Vui lòng đọc và tích đồng ý điều khoản")
                                        .font(ZevTheme.Typography.caption(12))
                                        .foregroundColor(ZevTheme.Colors.textMuted)
                                }
                            }
                            
                            Button(action: {
                                withAnimation(.spring(response: 0.25)) {
                                    isTermsAccepted.toggle()
                                    UserDefaults.standard.set(isTermsAccepted, forKey: AppConfig.UserDefaultsKeys.termsAccepted)
                                }
                            }) {
                                HStack(alignment: .top, spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isTermsAccepted ? ZevTheme.Colors.primary : ZevTheme.Colors.surface2)
                                            .frame(width: 22, height: 22)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .stroke(isTermsAccepted ? ZevTheme.Colors.primary : ZevTheme.Colors.border, lineWidth: 1.5)
                                            )
                                        
                                        if isTermsAccepted {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    
                                    Text("Tôi đã đọc, hiểu rõ và đồng ý với tất cả điều khoản sử dụng ứng dụng Zev.")
                                        .font(ZevTheme.Typography.caption(13))
                                        .foregroundColor(isTermsAccepted ? ZevTheme.Colors.text : ZevTheme.Colors.textMuted)
                                        .multilineTextAlignment(.leading)
                                    
                                    Spacer()
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            Button(action: { showTermsSheet = true }) {
                                Text("Xem nội dung điều khoản sử dụng chi tiết →")
                                    .font(ZevTheme.Typography.caption(12))
                                    .foregroundColor(ZevTheme.Colors.primary)
                            }
                        }
                    }
                    
                    // MARK: - Next Button (Tiếp Theo)
                    VStack(spacing: 10) {
                        Button(action: proceedToLogin) {
                            HStack(spacing: 8) {
                                Text("Tiếp Theo")
                                    .font(ZevTheme.Typography.body(16))
                                    .fontWeight(.bold)
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 15, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(isTermsAccepted ? ZevTheme.Gradients.primary : LinearGradient(colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing))
                            .foregroundColor(isTermsAccepted ? .white : Color.white.opacity(0.4))
                            .cornerRadius(ZevTheme.Radius.md)
                            .shadow(color: isTermsAccepted ? ZevTheme.Colors.primary.opacity(0.4) : .clear, radius: 12, x: 0, y: 4)
                        }
                        .disabled(!isTermsAccepted)
                        
                        if !isTermsAccepted {
                            Text("⚠️ Vui lòng tích chọn đồng ý điều khoản để tiếp tục.")
                                .font(ZevTheme.Typography.caption(11))
                                .foregroundColor(ZevTheme.Colors.warning)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
                .padding(.horizontal, 20)
            }
        }
        .onAppear {
            checkCurrentNotificationStatus()
            selectedLanguage = UserDefaults.standard.string(forKey: AppConfig.UserDefaultsKeys.selectedLanguage) ?? "vi"
            isTermsAccepted = UserDefaults.standard.bool(forKey: AppConfig.UserDefaultsKeys.termsAccepted)
        }
        .sheet(isPresented: $showTermsSheet) {
            TermsSheetView()
        }
    }
    
    // MARK: - Actions
    
    private func checkCurrentNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationsAllowed = (settings.authorizationStatus == .authorized)
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                withAnimation {
                    notificationsAllowed = granted
                }
            }
        }
    }
    
    private func proceedToLogin() {
        guard isTermsAccepted else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.35)) {
            appState.completeOnboarding()
        }
    }
}

// MARK: - TermsSheetView

struct TermsSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Điều Khoản Sử Dụng Zev")
                        .font(ZevTheme.Typography.title(18))
                        .foregroundColor(ZevTheme.Colors.text)
                    Spacer()
                    Button("Đóng") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(ZevTheme.Colors.primary)
                }
                .padding(20)
                .background(ZevTheme.Colors.surface)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("1. Mục đích sử dụng")
                            .font(ZevTheme.Typography.heading(15))
                            .foregroundColor(ZevTheme.Colors.text)
                        Text("Ứng dụng Zev là phần mềm nghiên cứu và quản lý dữ liệu thiết bị cá nhân. Người dùng hoàn toàn chịu trách nhiệm về cách thức sử dụng phần mềm trên thiết bị của mình.")
                            .font(ZevTheme.Typography.body(13))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        
                        Text("2. Bản quyền Key và Khóa Thiết Bị (HWID)")
                            .font(ZevTheme.Typography.heading(15))
                            .foregroundColor(ZevTheme.Colors.text)
                        Text("Mỗi mã Key chỉ được kích hoạt và liên kết cố định với 01 thiết bị duy nhất thông qua mã định danh phần cứng (HWID). Mọi hành vi chia sẻ key hoặc cố tình can thiệp hệ thống sẽ dẫn đến thu hồi key vĩnh viễn.")
                            .font(ZevTheme.Typography.body(13))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        
                        Text("3. Bản vá và Dữ liệu Ứng Dụng")
                            .font(ZevTheme.Typography.heading(15))
                            .foregroundColor(ZevTheme.Colors.text)
                        Text("Các tính năng áp dụng bản vá (.3105, cache, config) được tải trực tiếp từ máy chủ. Chúng tôi luôn khuyến nghị bạn sao lưu dữ liệu trước khi thực hiện bất kỳ thao tác nào.")
                            .font(ZevTheme.Typography.body(13))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                    }
                    .padding(20)
                }
            }
        }
    }
}
