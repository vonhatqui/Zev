import SwiftUI

// MARK: - ZevTheme
// Design system toàn cục cho ứng dụng

enum ZevTheme {
    
    // ─── Colors ─────────────────────────────────────────────────────────────
    enum Colors {
        // Ưu tiên nền trắng sáng, thanh thoát và sạch sẽ
        static let background       = Color(hex: "#F8FAFC") // Trắng ngà sang trọng
        static let surface          = Color(hex: "#FFFFFF") // Trắng thuần khiết cho Card
        static let surface2         = Color(hex: "#F1F5F9") // Ô nhập dữ liệu, container phụ
        static let surface3         = Color(hex: "#E2E8F0") // Hover / Divider
        static let border           = Color(hex: "#E2E8F0") // Viền mỏng cao cấp
        
        static let primary          = Color(hex: "#4F46E5") // Indigo sắc nét
        static let primaryDim       = Color(hex: "#4338CA")
        static let primaryGlow      = Color(hex: "#4F46E5").opacity(0.12)
        
        static let success          = Color(hex: "#16A34A") // Xanh lá đậm chuẩn Apple
        static let warning          = Color(hex: "#D97706") // Vàng cam
        static let danger           = Color(hex: "#DC2626") // Đỏ
        static let info             = Color(hex: "#2563EB") // Xanh dương
        
        // Chữ đen rõ nét, độ tương phản tuyệt đối trên nền trắng
        static let text             = Color(hex: "#0F172A") // Đen đậm nét
        static let textMuted        = Color(hex: "#475569") // Xám đen tinh tế
        static let textDim          = Color(hex: "#64748B") // Xám nhạt
        
        static let gradientStart    = Color(hex: "#4F46E5")
        static let gradientEnd      = Color(hex: "#7C3AED")
    }
    
    // ─── Gradients ──────────────────────────────────────────────────────────
    enum Gradients {
        static let primary = LinearGradient(
            colors: [Colors.gradientStart, Colors.gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let background = LinearGradient(
            colors: [Color(hex: "#FFFFFF"), Color(hex: "#F8FAFC")],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let card = LinearGradient(
            colors: [Color(hex: "#FFFFFF"), Color(hex: "#F8FAFC")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // ─── Typography ──────────────────────────────────────────────────────────
    enum Typography {
        static func title(_ size: CGFloat = 24) -> Font {
            .system(size: size, weight: .bold, design: .rounded)
        }
        static func heading(_ size: CGFloat = 18) -> Font {
            .system(size: size, weight: .semibold, design: .default)
        }
        static func body(_ size: CGFloat = 15) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }
        static func caption(_ size: CGFloat = 12) -> Font {
            .system(size: size, weight: .medium, design: .default)
        }
        static func mono(_ size: CGFloat = 14) -> Font {
            .system(size: size, weight: .semibold, design: .monospaced)
        }
    }
    
    // ─── Spacing ────────────────────────────────────────────────────────────
    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
        static let xxl: CGFloat = 48
    }
    
    // ─── Corner Radius ───────────────────────────────────────────────────────
    enum Radius {
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 12
        static let lg: CGFloat  = 16
        static let xl: CGFloat  = 24
        static let full: CGFloat = 999
    }
    
    // ─── Shadows ─────────────────────────────────────────────────────────────
    enum Shadow {
        static let sm = Color.black.opacity(0.04)
        static let md = Color.black.opacity(0.07)
        static let glow = Colors.primary.opacity(0.12)
    }
    
    // ─── Animation ───────────────────────────────────────────────────────────
    enum Animation {
        static let fast    = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let normal  = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let spring  = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
    }
}

// MARK: - Rainbow LED Animation Component
// Hiệu ứng chữ đổi 7 màu LED liên tục chuẩn RGB Neon
struct RainbowLEDText: View {
    let text: String
    var fontSize: CGFloat = 26
    var fontWeight: Font.Weight = .black
    var tracking: CGFloat = 2.0
    
    @State private var isAnimating: Bool = false
    
    // 7 màu LED cầu vồng: Đỏ, Cam, Vàng, Lục, Lam, Chàm, Tím và lặp lại
    private let rainbowColors: [Color] = [
        Color(hex: "#FF0000"), // Đỏ
        Color(hex: "#FF7700"), // Cam
        Color(hex: "#FFDD00"), // Vàng
        Color(hex: "#00E676"), // Lục
        Color(hex: "#00E5FF"), // Lam
        Color(hex: "#2979FF"), // Chàm
        Color(hex: "#D500F9"), // Tím
        Color(hex: "#FF007F"), // Hồng
        Color(hex: "#FF0000")  // Lặp lại
    ]
    
    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: fontWeight, design: .rounded))
            .tracking(tracking)
            .foregroundStyle(
                LinearGradient(
                    colors: rainbowColors,
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .hueRotation(.degrees(isAnimating ? 360 : 0))
            .shadow(color: Color(hex: "#00E5FF").opacity(0.35), radius: 6, x: 0, y: 0)
            .shadow(color: Color(hex: "#D500F9").opacity(0.3), radius: 10, x: 0, y: 0)
            .onAppear {
                withAnimation(
                    .linear(duration: 3.0)
                    .repeatForever(autoreverses: false)
                ) {
                    isAnimating = true
                }
            }
    }
}

// MARK: - Color Extension (Hex Support)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red:   Double(r) / 255,
                  green: Double(g) / 255,
                  blue:  Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - View Modifiers

struct ZevCardModifier: ViewModifier {
    var padding: CGFloat = 16
    
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(ZevTheme.Colors.surface)
            .cornerRadius(ZevTheme.Radius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: ZevTheme.Radius.lg)
                    .stroke(ZevTheme.Colors.border, lineWidth: 1)
            )
    }
}

struct ZevButtonStyle: ButtonStyle {
    var variant: ButtonVariant = .primary
    
    enum ButtonVariant {
        case primary, secondary, danger, ghost
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(backgroundColor(pressed: configuration.isPressed))
            .foregroundColor(foregroundColor)
            .cornerRadius(ZevTheme.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                    .stroke(borderColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(ZevTheme.Animation.fast, value: configuration.isPressed)
    }
    
    private func backgroundColor(pressed: Bool) -> Color {
        switch variant {
        case .primary:   return pressed ? ZevTheme.Colors.primaryDim : ZevTheme.Colors.primary
        case .secondary: return pressed ? ZevTheme.Colors.surface3 : ZevTheme.Colors.surface2
        case .danger:    return pressed ? ZevTheme.Colors.danger : ZevTheme.Colors.danger.opacity(0.15)
        case .ghost:     return pressed ? ZevTheme.Colors.surface2 : .clear
        }
    }
    
    private var foregroundColor: Color {
        switch variant {
        case .primary:   return .white
        case .secondary: return ZevTheme.Colors.text
        case .danger:    return ZevTheme.Colors.danger
        case .ghost:     return ZevTheme.Colors.textMuted
        }
    }
    
    private var borderColor: Color {
        switch variant {
        case .primary:   return ZevTheme.Colors.primary
        case .secondary: return ZevTheme.Colors.border
        case .danger:    return ZevTheme.Colors.danger.opacity(0.4)
        case .ghost:     return .clear
        }
    }
}

extension View {
    func zevCard(padding: CGFloat = 16) -> some View {
        modifier(ZevCardModifier(padding: padding))
    }
    
    func shimmer() -> some View {
        self.redacted(reason: .placeholder)
    }
}
