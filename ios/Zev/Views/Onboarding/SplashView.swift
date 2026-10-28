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
                
                // Logo Container (Sạch sẽ, tải tức thì)
                ZevCachedImage(
                    urlString: AppConfig.appLogoURL,
                    fallbackSystemIcon: "bolt.shield.fill",
                    width: 96,
                    height: 96,
                    cornerRadius: 22
                )
                .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 4)
                .scaleEffect(isAnimating ? 1.05 : 0.95)
                
                // Title & Subtitle
                VStack(spacing: 8) {
                    RainbowLEDText(text: "ZEV", fontSize: 40)
                    
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
