import SwiftUI

// MARK: - HomeView
// Trang chủ ứng dụng Zev hiển thị thông tin bản quyền, thông báo máy chủ và các tính năng nhanh

struct HomeView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var isRefreshing: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                ZevTheme.Colors.background
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        
                        // Header
                        headerSection
                        
                        // License Status Card
                        licenseCard
                        
                        // Server Announcement Banner
                        if let announcement = appState.appConfig?.config["announcement_text"], !announcement.isEmpty {
                            announcementBanner(announcement)
                        }
                        
                        // Quick Actions Grid
                        quickActionsSection
                        
                        // Device Status
                        deviceStatusSection
                        
                        Spacer(minLength: 32)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationBarHidden(true)
            .refreshable {
                await refreshData()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - Header
    private var headerSection: some View {
        HStack {
            HStack(spacing: 12) {
                AsyncImage(url: URL(string: AppConfig.appLogoURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    default:
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(ZevTheme.Colors.surface2)
                                .frame(width: 42, height: 42)
                            Image(systemName: "bolt.fill")
                                .foregroundColor(ZevTheme.Colors.primary)
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("ZEV")
                        .font(ZevTheme.Typography.title(20))
                        .foregroundStyle(ZevTheme.Gradients.primary)
                    
                    Text("iOS System Enhancement")
                        .font(ZevTheme.Typography.caption(11))
                        .foregroundColor(ZevTheme.Colors.textMuted)
                }
            }
            
            Spacer()
            
            // Server Status Indicator
            HStack(spacing: 6) {
                Circle()
                    .fill(ZevTheme.Colors.success)
                    .frame(width: 8, height: 8)
                    .shadow(color: ZevTheme.Colors.success.opacity(0.8), radius: 4)
                
                Text("Trực tuyến")
                    .font(ZevTheme.Typography.caption(12))
                    .foregroundColor(ZevTheme.Colors.success)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(ZevTheme.Colors.surface2)
            .cornerRadius(ZevTheme.Radius.full)
            .overlay(
                RoundedRectangle(cornerRadius: ZevTheme.Radius.full)
                    .stroke(ZevTheme.Colors.border, lineWidth: 1)
            )
        }
    }
    
    // MARK: - License Card
    private var licenseCard: some View {
        ZevCard(borderGlow: true) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 16))
                            .foregroundColor(ZevTheme.Colors.primary)
                        
                        Text("BẢN QUYỀN ĐÃ KÍCH HOẠT")
                            .font(ZevTheme.Typography.caption(12))
                            .fontWeight(.bold)
                            .foregroundColor(ZevTheme.Colors.text)
                    }
                    
                    Spacer()
                    
                    StatusBadge(
                        title: appState.keyInfo?.isLifetime == true ? "VĨNH VIỄN" : "VIP KEY",
                        color: ZevTheme.Colors.primary
                    )
                }
                
                // Key Code display
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Mã bản quyền:")
                            .font(ZevTheme.Typography.caption(11))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        
                        Text(formatKeyDisplay(appState.activationKey))
                            .font(ZevTheme.Typography.mono(16))
                            .foregroundColor(ZevTheme.Colors.text)
                    }
                    
                    Spacer()
                    
                    Button(action: copyKey) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 14))
                            .foregroundColor(ZevTheme.Colors.primary)
                            .padding(8)
                            .background(ZevTheme.Colors.surface3)
                            .clipShape(Circle())
                    }
                }
                
                Divider()
                    .background(ZevTheme.Colors.border)
                
                // Expiry info
                HStack {
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        
                        Text("Hạn sử dụng: ")
                            .font(ZevTheme.Typography.caption(12))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        
                        Text(appState.keyInfo?.displayExpiry ?? "Đang kiểm tra...")
                            .font(ZevTheme.Typography.caption(12))
                            .fontWeight(.semibold)
                            .foregroundColor(ZevTheme.Colors.text)
                    }
                    
                    Spacer()
                    
                    Link(destination: URL(string: "https://t.me/zev_support")!) {
                        Text("Gia hạn")
                            .font(ZevTheme.Typography.caption(12))
                            .fontWeight(.semibold)
                            .foregroundColor(ZevTheme.Colors.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Announcement Banner
    private func announcementBanner(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "megaphone.fill")
                .foregroundColor(ZevTheme.Colors.warning)
                .font(.system(size: 16))
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Thông báo hệ thống")
                    .font(ZevTheme.Typography.caption(11))
                    .fontWeight(.bold)
                    .foregroundColor(ZevTheme.Colors.warning)
                
                Text(text)
                    .font(ZevTheme.Typography.body(13))
                    .foregroundColor(ZevTheme.Colors.text)
            }
            Spacer()
        }
        .padding(14)
        .background(ZevTheme.Colors.surface2)
        .cornerRadius(ZevTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                .stroke(ZevTheme.Colors.warning.opacity(0.3), lineWidth: 1)
        )
    }
    
    // MARK: - Quick Actions Grid
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Truy Cập Nhanh")
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                
                // Action 1: Refresh Key
                Button(action: {
                    Task { await refreshData() }
                }) {
                    quickActionItem(
                        icon: "arrow.clockwise.circle.fill",
                        title: "Đồng bộ Key",
                        desc: "Cập nhật thời hạn",
                        iconColor: ZevTheme.Colors.primary
                    )
                }
                
                // Action 2: Support Telegram
                Link(destination: URL(string: "https://t.me/zev_support")!) {
                    quickActionItem(
                        icon: "paperplane.fill",
                        title: "Hỗ trợ Kỹ thuật",
                        desc: "Kênh Telegram",
                        iconColor: Color(hex: "#0088cc")
                    )
                }
                
                // Action 3: Discord Community
                Link(destination: URL(string: "https://discord.gg/")!) {
                    quickActionItem(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "Cộng đồng Zev",
                        desc: "Discord Server",
                        iconColor: Color(hex: "#5865F2")
                    )
                }
                
                // Action 4: Server URL
                NavigationLink(destination: SettingsView()) {
                    quickActionItem(
                        icon: "gearshape.fill",
                        title: "Cài đặt & API",
                        desc: "Đổi máy chủ",
                        iconColor: ZevTheme.Colors.textMuted
                    )
                }
            }
        }
    }
    
    private func quickActionItem(icon: String, title: String, desc: String, iconColor: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ZevTheme.Typography.heading(13))
                    .foregroundColor(ZevTheme.Colors.text)
                
                Text(desc)
                    .font(ZevTheme.Typography.caption(11))
                    .foregroundColor(ZevTheme.Colors.textMuted)
            }
            
            Spacer()
        }
        .padding(14)
        .background(ZevTheme.Colors.surface2)
        .cornerRadius(ZevTheme.Radius.md)
        .overlay(
            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                .stroke(ZevTheme.Colors.border, lineWidth: 1)
        )
    }
    
    // MARK: - Device Status Section
    private var deviceStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Thiết Bị Của Bạn")
            
            ZevCard {
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 16))
                            .foregroundColor(ZevTheme.Colors.primary)
                        
                        Text(DeviceService.shared.deviceCommercialName)
                            .font(ZevTheme.Typography.heading(14))
                            .foregroundColor(ZevTheme.Colors.text)
                        
                        Spacer()
                        
                        StatusBadge(title: "iOS " + DeviceService.shared.iosVersion, color: ZevTheme.Colors.success)
                    }
                    
                    Divider().background(ZevTheme.Colors.border)
                    
                    HStack {
                        Text("HWID Liên kết:")
                            .font(ZevTheme.Typography.caption(12))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        Spacer()
                        Text(String(DeviceService.shared.deviceIdentifier.prefix(20)) + "...")
                            .font(ZevTheme.Typography.mono(11))
                            .foregroundColor(ZevTheme.Colors.textDim)
                    }
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func formatKeyDisplay(_ key: String) -> String {
        guard key.count >= 12 else { return key }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)-****-****-\(suffix)"
    }
    
    private func copyKey() {
        UIPasteboard.general.string = appState.activationKey
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func refreshData() async {
        await appState.refreshKeyStatus()
    }
}
