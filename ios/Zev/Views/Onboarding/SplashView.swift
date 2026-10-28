import SwiftUI

// MARK: - SplashView
// Màn hình khởi động ZEV với logo động và hiệu ứng phát sáng

struct SplashView: View {
    @State private var isAnimating: Bool = false
    @State private var glowOpacity: Double = 0.3
    
    var body: some View {
        ZStack {
            // Background
            ZevTheme.Colors.background
                .ignoresSafeArea()
            
            // Glowing Ambient Light
            RadialGradient(
                gradient: Gradient(colors: [
                    ZevTheme.Colors.primary.opacity(glowOpacity),
                    Color.clear
                ]),
                center: .center,
                startRadius: 20,
                endRadius: 220
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Spacer()
                
                // Logo Container
                ZStack {
                    Circle()
                        .fill(ZevTheme.Colors.surface2)
                        .frame(width: 120, height: 120)
                        .overlay(
                            Circle()
                                .stroke(ZevTheme.Gradients.primary, lineWidth: 2)
                        )
                        .shadow(color: ZevTheme.Colors.primary.opacity(0.5), radius: 24, x: 0, y: 0)
                    
                    AsyncImage(url: URL(string: AppConfig.appLogoURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                        default:
                            Image(systemName: "bolt.shield.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(ZevTheme.Gradients.primary)
                        }
                    }
                    .scaleEffect(isAnimating ? 1.05 : 0.95)
                }
                
                // Title & Subtitle
                VStack(spacing: 6) {
                    Text("ZEV")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(ZevTheme.Gradients.primary)
                        .tracking(3)
                    
                    Text("iOS System & Game Enhancement")
                        .font(ZevTheme.Typography.caption(13))
                        .foregroundColor(ZevTheme.Colors.textMuted)
                }
                
                Spacer()
                
                // Loading Progress Indicator
                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: ZevTheme.Colors.primary))
                        .scaleEffect(1.1)
                    
                    Text("Đang đồng bộ máy chủ...")
                        .font(ZevTheme.Typography.caption(12))
                        .foregroundColor(ZevTheme.Colors.textDim)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
            ) {
                isAnimating = true
                glowOpacity = 0.6
            }
        }
    }
}
