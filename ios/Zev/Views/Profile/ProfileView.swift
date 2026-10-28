import SwiftUI

// MARK: - ProfileView (Tab Cá Nhân)
// Hiển thị hỗ trợ Zalo: 0365829172, Mua Key, Thời gian key, và Kiểm tra hỗ trợ iOS 3105-2.0

struct ProfileView: View {
    @EnvironmentObject var appState: AppStateManager
    
    @State private var showLogoutAlert: Bool = false
    @State private var isCopiedKey: Bool = false
    @State private var isCopiedZalo: Bool = false
    @State private var showIOSInfoSheet: Bool = false
    
    private let deviceService = DeviceService.shared
    
    var body: some View {
        ZStack {
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    
                    // Top Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                RainbowLEDText(text: "ZEV", fontSize: 22)
                                Text("Cá Nhân & Hỗ Trợ")
                                    .font(ZevTheme.Typography.title(20))
                                    .foregroundColor(ZevTheme.Colors.text)
                            }
                            Text("Quản lý bản quyền, liên hệ và trạng thái hệ thống")
                                .font(ZevTheme.Typography.caption(12))
                                .foregroundColor(ZevTheme.Colors.textMuted)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    
                    // MARK: - Card 1: Hỗ Trợ Zalo & Mua Key (Nổi Bật)
                    ZevCard(borderGlow: true) {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Color(hex: "#0068FF").opacity(0.18))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: "message.fill")
                                        .foregroundColor(Color(hex: "#0068FF"))
                                        .font(.system(size: 16))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("KÊNH HỖ TRỢ & MUA KEY")
                                        .font(ZevTheme.Typography.caption(12))
                                        .fontWeight(.bold)
                                        .foregroundColor(ZevTheme.Colors.text)
                                    Text("Liên hệ quản trị viên Zev để mua key hoặc báo lỗi")
                                        .font(ZevTheme.Typography.caption(11))
                                        .foregroundColor(ZevTheme.Colors.textMuted)
                                }
                                
                                Spacer()
                            }
                            
                            // Zalo Info Row
                            HStack {
                                HStack(spacing: 8) {
                                    Text("💬")
                                        .font(.system(size: 20))
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text("Zalo Admin:")
                                            .font(ZevTheme.Typography.caption(11))
                                            .foregroundColor(ZevTheme.Colors.textMuted)
                                        Text("0365829172")
                                            .font(ZevTheme.Typography.mono(16))
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: copyZalo) {
                                    HStack(spacing: 4) {
                                        Image(systemName: isCopiedZalo ? "checkmark" : "doc.on.clipboard")
                                        Text(isCopiedZalo ? "Đã chép" : "Sao chép")
                                    }
                                    .font(ZevTheme.Typography.caption(12))
                                    .foregroundColor(ZevTheme.Colors.primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(ZevTheme.Colors.surface2)
                                    .cornerRadius(ZevTheme.Radius.sm)
                                }
                            }
                            .padding(12)
                            .background(ZevTheme.Colors.surface2)
                            .cornerRadius(ZevTheme.Radius.md)
                            
                            // Action Buttons
                            HStack(spacing: 10) {
                                Button(action: openZalo) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "paperplane.fill")
                                        Text("Mở Chat Zalo")
                                    }
                                    .font(ZevTheme.Typography.body(13))
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(LinearGradient(colors: [Color(hex: "#0068FF"), Color(hex: "#0088FF")], startPoint: .leading, endPoint: .trailing))
                                    .cornerRadius(ZevTheme.Radius.md)
                                }
                                
                                Button(action: openZalo) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "cart.fill")
                                        Text("Mua Key / Gia Hạn")
                                    }
                                    .font(ZevTheme.Typography.body(13))
                                    .fontWeight(.bold)
                                    .foregroundColor(ZevTheme.Colors.primary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(ZevTheme.Colors.surface2)
                                    .cornerRadius(ZevTheme.Radius.md)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                            .stroke(ZevTheme.Colors.primary.opacity(0.4), lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // MARK: - Card 2: Thông Tin Thời Gian Key
                    ZevCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(ZevTheme.Colors.primary)
                                    .font(.system(size: 15))
                                
                                Text("THỜI GIAN & THÔNG TIN KEY")
                                    .font(ZevTheme.Typography.caption(12))
                                    .fontWeight(.bold)
                                    .foregroundColor(ZevTheme.Colors.text)
                                
                                Spacer()
                                
                                StatusBadge(
                                    title: appState.keyInfo?.isLifetime == true ? "VĨNH VIỄN" : "VIP",
                                    color: ZevTheme.Colors.primary
                                )
                            }
                            
                            // Mã Key
                            HStack {
                                Text(appState.activationKey)
                                    .font(ZevTheme.Typography.mono(14))
                                    .foregroundColor(ZevTheme.Colors.text)
                                
                                Spacer()
                                
                                Button(action: copyKey) {
                                    Image(systemName: isCopiedKey ? "checkmark" : "doc.on.clipboard")
                                        .font(.system(size: 13))
                                        .foregroundColor(ZevTheme.Colors.primary)
                                }
                            }
                            .padding(12)
                            .background(ZevTheme.Colors.surface2)
                            .cornerRadius(ZevTheme.Radius.sm)
                            
                            VStack(spacing: 8) {
                                infoRow(title: "Thời gian của key:", value: appState.keyInfo?.displayExpiry ?? "—")
                                infoRow(title: "Trạng thái:", value: "Đang hoạt động (Active)")
                                infoRow(title: "Loại key:", value: appState.keyInfo?.isLifetime == true ? "Trọn đời" : "Có thời hạn")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // MARK: - Card 3: Kiểm Tra Hỗ Trợ iOS (3105-2.0 Policy)
                    ZevCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Image(systemName: "shield.lefthalf.filled")
                                    .foregroundColor(SupportPolicy.isCurrentDeviceSupported ? ZevTheme.Colors.success : ZevTheme.Colors.danger)
                                    .font(.system(size: 15))
                                
                                Text("KIỂM TRA HỖ TRỢ iOS (3105-2.0)")
                                    .font(ZevTheme.Typography.caption(12))
                                    .fontWeight(.bold)
                                    .foregroundColor(ZevTheme.Colors.text)
                                
                                Spacer()
                                
                                StatusBadge(
                                    title: SupportPolicy.currentSupportBadgeText,
                                    color: SupportPolicy.isCurrentDeviceSupported ? ZevTheme.Colors.success : ZevTheme.Colors.danger
                                )
                            }
                            
                            VStack(spacing: 8) {
                                infoRow(title: "Thiết bị:", value: deviceService.deviceCommercialName)
                                infoRow(title: "Phiên bản iOS:", value: "iOS " + deviceService.iosVersion)
                                infoRow(title: "Khả năng hỗ trợ:", value: SupportPolicy.isCurrentDeviceSupported ? "Có hỗ trợ (Verified)" : "Không hỗ trợ")
                            }
                            
                            Button(action: { showIOSInfoSheet = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "list.bullet.rectangle")
                                    Text("Xem danh sách các phiên bản iOS được hỗ trợ →")
                                }
                                .font(ZevTheme.Typography.caption(12))
                                .foregroundColor(ZevTheme.Colors.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // MARK: - Card 4: Tùy Chọn & Thao Tác
                    ZevCard {
                        VStack(spacing: 12) {
                            // Nút Đổi Game
                            Button(action: {
                                withAnimation {
                                    appState.switchGame()
                                }
                            }) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundColor(ZevTheme.Colors.primary)
                                    Text("Đổi Tựa Game (Free Fire Thường / MAX)")
                                        .font(ZevTheme.Typography.body(14))
                                        .foregroundColor(ZevTheme.Colors.text)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(ZevTheme.Colors.textDim)
                                }
                                .padding(.vertical, 4)
                            }
                            
                            Divider().background(ZevTheme.Colors.border)
                            
                            // Nút Xóa Cache
                            Button(action: clearLocalCache) {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(ZevTheme.Colors.warning)
                                    Text("Xóa Cache Ứng Dụng")
                                        .font(ZevTheme.Typography.body(14))
                                        .foregroundColor(ZevTheme.Colors.text)
                                    Spacer()
                                    Text("Làm mới")
                                        .font(ZevTheme.Typography.caption(12))
                                        .foregroundColor(ZevTheme.Colors.textDim)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // MARK: - Logout Button
                    Button(action: { showLogoutAlert = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Đăng Xuất Key Khỏi Thiết Bị")
                        }
                        .font(ZevTheme.Typography.body(14))
                        .fontWeight(.semibold)
                        .foregroundColor(ZevTheme.Colors.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(ZevTheme.Colors.danger.opacity(0.12))
                        .cornerRadius(ZevTheme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                .stroke(ZevTheme.Colors.danger.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 36)
                }
            }
        }
        .alert(isPresented: $showLogoutAlert) {
            Alert(
                title: Text("Xác nhận đăng xuất?"),
                message: Text("Mã key sẽ được gỡ khỏi thiết bị này. Bạn có thể đăng nhập lại bất kỳ lúc nào."),
                primaryButton: .destructive(Text("Đăng xuất")) {
                    withAnimation {
                        appState.logout()
                    }
                },
                secondaryButton: .cancel(Text("Hủy"))
            )
        }
        .sheet(isPresented: $showIOSInfoSheet) {
            IOSSupportListSheet()
        }
    }
    
    // MARK: - Actions
    
    private func copyZalo() {
        UIPasteboard.general.string = "0365829172"
        isCopiedZalo = true
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopiedZalo = false
        }
    }
    
    private func copyKey() {
        UIPasteboard.general.string = appState.activationKey
        isCopiedKey = true
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCopiedKey = false
        }
    }
    
    private func openZalo() {
        if let url = URL(string: "https://zalo.me/0365829172") {
            UIApplication.shared.open(url)
        }
    }
    
    private func clearLocalCache() {
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(ZevTheme.Typography.caption(12))
                .foregroundColor(ZevTheme.Colors.textMuted)
            Spacer()
            Text(value)
                .font(ZevTheme.Typography.body(13))
                .foregroundColor(ZevTheme.Colors.text)
        }
    }
}

// MARK: - IOSSupportListSheet
// Danh sách chi tiết các phiên bản iOS được xác minh từ dự án 3105-2.0

struct IOSSupportListSheet: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        ZStack {
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Danh Sách iOS Hỗ Trợ (3105-2.0)")
                        .font(ZevTheme.Typography.title(17))
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
                        Text("Các phiên bản hệ thống đã được xác minh:")
                            .font(ZevTheme.Typography.body(13))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        
                        supportItem(title: "iOS 17", range: "17.0 đến 17.7.x", status: "Có hỗ trợ")
                        supportItem(title: "iOS 18", range: "18.0 đến 18.7.1", status: "Có hỗ trợ")
                        supportItem(title: "iOS 26", range: "26.0 đến 26.6.1", status: "Có hỗ trợ")
                        supportItem(title: "iOS 27 Beta 1", range: "Build 24A5355q", status: "Có hỗ trợ")
                        supportItem(title: "iOS 27 Beta 2", range: "Build 24A5370h", status: "Có hỗ trợ")
                        supportItem(title: "iOS 27 Beta 3 / Public Beta 1", range: "Build 24A5380h", status: "Có hỗ trợ")
                        supportItem(title: "iOS 27 Beta 4 / Public Beta 2", range: "Build 24A5390f", status: "Có hỗ trợ")
                        
                        Text("⚠️ Lưu ý: Những build iOS không nằm trong danh sách trên sẽ được hệ thống đánh dấu là 'Chưa hỗ trợ'.")
                            .font(ZevTheme.Typography.caption(12))
                            .foregroundColor(ZevTheme.Colors.warning)
                            .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
        }
    }
    
    private func supportItem(title: String, range: String, status: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ZevTheme.Typography.heading(14))
                    .foregroundColor(ZevTheme.Colors.text)
                Text(range)
                    .font(ZevTheme.Typography.mono(12))
                    .foregroundColor(ZevTheme.Colors.textMuted)
            }
            Spacer()
            Text("🟢 " + status)
                .font(ZevTheme.Typography.caption(12))
                .fontWeight(.bold)
                .foregroundColor(ZevTheme.Colors.success)
        }
        .padding(12)
        .background(ZevTheme.Colors.surface2)
        .cornerRadius(ZevTheme.Radius.md)
    }
}
