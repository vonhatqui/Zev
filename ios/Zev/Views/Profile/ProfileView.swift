import SwiftUI

// MARK: - ProfileView
// Màn hình thông tin tài khoản, bản quyền key và quản trị thiết bị

struct ProfileView: View {
    @EnvironmentObject var appState: AppStateManager
    
    @State private var isKeyVisible: Bool = false
    @State private var showLogoutAlert: Bool = false
    @State private var isRefreshing: Bool = false
    @State private var toastMessage: String? = nil
    
    var body: some View {
        NavigationView {
            ZStack {
                ZevTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // Header
                        HStack {
                            Text("Tài Khoản & Bản Quyền")
                                .font(ZevTheme.Typography.title(22))
                                .foregroundColor(ZevTheme.Colors.text)
                            Spacer()
                            
                            NavigationLink(destination: SettingsView()) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(ZevTheme.Colors.textMuted)
                                    .padding(8)
                                    .background(ZevTheme.Colors.surface2)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        // Key Information Card
                        keyInfoCard
                        
                        // Device Binding Card
                        deviceBindingCard
                        
                        // Actions Section
                        actionsSection
                        
                        // Logout / Deactivate Button
                        ZevButton(title: "Hủy Kích Hoạt Thiết Bị", icon: "rectangle.portrait.and.arrow.right", style: .danger) {
                            showLogoutAlert = true
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        
                        Spacer(minLength: 32)
                    }
                }
            }
            .navigationBarHidden(true)
            .alert(isPresented: $showLogoutAlert) {
                Alert(
                    title: Text("Xác nhận hủy kích hoạt?"),
                    message: Text("Key của bạn sẽ được gỡ khỏi thiết bị này. Bạn sẽ cần nhập lại key để sử dụng."),
                    primaryButton: .destructive(Text("Hủy kích hoạt")) {
                        appState.logout()
                    },
                    secondaryButton: .cancel(Text("Quay lại"))
                )
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Key Info Card
    private var keyInfoCard: some View {
        ZevCard(borderGlow: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "key.fill")
                        .foregroundColor(ZevTheme.Colors.primary)
                        .font(.system(size: 16))
                    
                    Text("THÔNG TIN BẢN QUYỀN")
                        .font(ZevTheme.Typography.caption(12))
                        .fontWeight(.bold)
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    Spacer()
                    
                    StatusBadge(
                        title: appState.keyInfo?.isLifetime == true ? "VĨNH VIỄN" : "VIP KEY",
                        color: ZevTheme.Colors.primary
                    )
                }
                
                // Key Display
                HStack {
                    Text(isKeyVisible ? appState.activationKey : maskedKey(appState.activationKey))
                        .font(ZevTheme.Typography.mono(15))
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    Spacer()
                    
                    Button(action: { isKeyVisible.toggle() }) {
                        Image(systemName: isKeyVisible ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 14))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                    }
                    
                    Button(action: copyKey) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(ZevTheme.Colors.primary)
                    }
                }
                .padding(12)
                .background(ZevTheme.Colors.surface2)
                .cornerRadius(ZevTheme.Radius.md)
                
                // Details
                VStack(spacing: 8) {
                    rowDetail(title: "Trạng thái:", value: appState.keyInfo?.status.uppercased() ?? "ACTIVE")
                    rowDetail(title: "Hạn sử dụng:", value: appState.keyInfo?.displayExpiry ?? "—")
                    rowDetail(title: "Loại gói:", value: appState.keyInfo?.isLifetime == true ? "Trọn đời (Lifetime)" : "Định kỳ")
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Device Binding Card
    private var deviceBindingCard: some View {
        ZevCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(ZevTheme.Colors.info)
                        .font(.system(size: 16))
                    
                    Text("LIÊN KẾT PHẦN CỨNG (HWID)")
                        .font(ZevTheme.Typography.caption(12))
                        .fontWeight(.bold)
                        .foregroundColor(ZevTheme.Colors.text)
                    
                    Spacer()
                    
                    StatusBadge(title: "ĐÃ KHÓA", color: ZevTheme.Colors.info)
                }
                
                VStack(spacing: 8) {
                    rowDetail(title: "Tên thương mại:", value: DeviceService.shared.deviceCommercialName)
                    rowDetail(title: "Mã máy:", value: DeviceService.shared.deviceModelIdentifier)
                    rowDetail(title: "Hệ điều hành:", value: "iOS " + DeviceService.shared.iosVersion)
                    rowDetail(title: "HWID Identifier:", value: String(DeviceService.shared.deviceIdentifier.prefix(16)) + "...")
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 10) {
            // Action 1: Refresh Key
            ZevButton(title: "Đồng Bộ Lại Trạng Thái Key", icon: "arrow.clockwise", style: .secondary, isLoading: isRefreshing) {
                Task {
                    isRefreshing = true
                    await appState.refreshKeyStatus()
                    isRefreshing = false
                }
            }
            
            // Action 2: Extend / Support
            Link(destination: URL(string: "https://t.me/zev_support")!) {
                HStack {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(Color(hex: "#0088cc"))
                    Text("Gia Hạn Bản Quyền / Hỗ Trợ Telegram")
                        .font(ZevTheme.Typography.heading(14))
                        .foregroundColor(ZevTheme.Colors.text)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13))
                        .foregroundColor(ZevTheme.Colors.textDim)
                }
                .padding(14)
                .background(ZevTheme.Colors.surface2)
                .cornerRadius(ZevTheme.Radius.md)
                .overlay(
                    RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                        .stroke(ZevTheme.Colors.border, lineWidth: 1)
                )
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Helpers
    private func rowDetail(title: String, value: String) -> some View {
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
    
    private func maskedKey(_ key: String) -> String {
        guard key.count >= 12 else { return key }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)-••••-••••-\(suffix)"
    }
    
    private func copyKey() {
        UIPasteboard.general.string = appState.activationKey
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}
