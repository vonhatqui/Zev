import SwiftUI

// MARK: - ZevTheme
// Design system toàn cục cho ứng dụng

enum ZevTheme {
    
    // ─── Colors ─────────────────────────────────────────────────────────────
    enum Colors {
        static let background       = Color(hex: "#0A0B0F")
        static let surface          = Color(hex: "#111218")
        static let surface2         = Color(hex: "#1A1C26")
        static let surface3         = Color(hex: "#22253A")
        static let border           = Color(hex: "#2A2D3E")
        
        static let primary          = Color(hex: "#6C63FF")
        static let primaryDim       = Color(hex: "#4F48C4")
        static let primaryGlow      = Color(hex: "#6C63FF").opacity(0.25)
        
        static let success          = Color(hex: "#22C55E")
        static let warning          = Color(hex: "#F59E0B")
        static let danger           = Color(hex: "#EF4444")
        static let info             = Color(hex: "#3B82F6")
        
        static let text             = Color(hex: "#E4E6F0")
        static let textMuted        = Color(hex: "#8B91A8")
        static let textDim          = Color(hex: "#55596E")
        
        static let gradientStart    = Color(hex: "#6C63FF")
        static let gradientEnd      = Color(hex: "#A78BFA")
    }
    
    // ─── Gradients ──────────────────────────────────────────────────────────
    enum Gradients {
        static let primary = LinearGradient(
            colors: [Colors.gradientStart, Colors.gradientEnd],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        
        static let background = LinearGradient(
            colors: [Colors.background, Color(hex: "#0D0E16")],
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let card = LinearGradient(
            colors: [Colors.surface, Colors.surface2],
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
        static let sm = Color.black.opacity(0.3)
        static let md = Color.black.opacity(0.5)
        static let glow = Colors.primary.opacity(0.3)
    }
    
    // ─── Animation ───────────────────────────────────────────────────────────
    enum Animation {
        static let fast    = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let normal  = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let spring  = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
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
