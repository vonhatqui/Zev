import SwiftUI

// MARK: - OnboardingView
// Trải nghiệm giới thiệu tính năng Zev hiện đại trước khi kích hoạt key

struct OnboardingItem: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let description: String
    let highlight: String
}

struct OnboardingView: View {
    @EnvironmentObject var appState: AppStateManager
    @State private var currentPage: Int = 0
    
    private let pages: [OnboardingItem] = [
        OnboardingItem(
            icon: "key.viewfinder",
            title: "Bản Quyền Độc Quyền",
            description: "Xác thực thiết bị theo mã phần cứng HWID an toàn, chống chia sẻ trái phép và quản lý thời hạn minh bạch.",
            highlight: "Kích Hoạt Nhanh Chóng"
        ),
        OnboardingItem(
            icon: "gamecontroller.fill",
            title: "Hỗ Trợ Đa Dạng Tựa Game",
            description: "Khám phá danh sách game được hỗ trợ tối ưu, tải cấu hình và xem trạng thái tính năng thời gian thực.",
            highlight: "Tối Ưu Hóa Cực Đỉnh"
        ),
        OnboardingItem(
            icon: "arrow.down.doc.fill",
            title: "Phân Phối File Bảo Mật",
            description: "Cơ chế mã token tải về một lần độc quyền, tải dylib và bản vá mới nhất từ máy chủ CDN tốc độ cao.",
            highlight: "Tải Xuống Tốc Độ Cao"
        )
    ]
    
    var body: some View {
        ZStack {
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            // Decorative background lights
            VStack {
                Circle()
                    .fill(ZevTheme.Colors.primary.opacity(0.15))
                    .blur(radius: 80)
                    .frame(width: 260, height: 260)
                    .offset(x: currentPage == 0 ? -100 : (currentPage == 1 ? 0 : 100), y: -100)
                Spacer()
            }
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Skip Button
                HStack {
                    Spacer()
                    Button(action: {
                        appState.completeOnboarding()
                    }) {
                        Text("Bỏ qua")
                            .font(ZevTheme.Typography.body(14))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                    }
                }
                .padding(.top, 12)
                .padding(.horizontal, 16)
                
                // TabView Carousel
                TabView(selection: $currentPage) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        let item = pages[index]
                        VStack(spacing: 28) {
                            Spacer()
                            
                            // Feature Icon Card
                            ZStack {
                                RoundedRectangle(cornerRadius: 32)
                                    .fill(ZevTheme.Colors.surface2)
                                    .frame(width: 140, height: 140)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 32)
                                            .stroke(ZevTheme.Gradients.primary, lineWidth: 1.5)
                                    )
                                    .shadow(color: ZevTheme.Colors.primary.opacity(0.3), radius: 20, x: 0, y: 8)
                                
                                Image(systemName: item.icon)
                                    .font(.system(size: 56))
                                    .foregroundStyle(ZevTheme.Gradients.primary)
                            }
                            
                            // Highlight Chip
                            StatusBadge(title: item.highlight, color: ZevTheme.Colors.primary)
                            
                            // Texts
                            VStack(spacing: 12) {
                                Text(item.title)
                                    .font(ZevTheme.Typography.title(24))
                                    .foregroundColor(ZevTheme.Colors.text)
                                    .multilineTextAlignment(.center)
                                
                                Text(item.description)
                                    .font(ZevTheme.Typography.body(15))
                                    .foregroundColor(ZevTheme.Colors.textMuted)
                                    .multilineTextAlignment(.center)
                                    .lineSpacing(4)
                                    .padding(.horizontal, 32)
                            }
                            
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // Bottom Section: Dots & Button
                VStack(spacing: 24) {
                    // Custom Indicators
                    HStack(spacing: 8) {
                        ForEach(0..<pages.count, id: \.self) { index in
                            Capsule()
                                .fill(currentPage == index ? ZevTheme.Colors.primary : ZevTheme.Colors.border)
                                .frame(width: currentPage == index ? 24 : 8, height: 8)
                                .animation(.spring(), value: currentPage)
                        }
                    }
                    
                    // Action Button
                    if currentPage == pages.count - 1 {
                        ZevButton(title: "Bắt đầu kích hoạt Zev", icon: "arrow.right", style: .primary) {
                            appState.completeOnboarding()
                        }
                    } else {
                        ZevButton(title: "Tiếp tục", icon: "chevron.right", style: .secondary) {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}
