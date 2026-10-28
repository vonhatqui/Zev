import SwiftUI

// MARK: - ZevCard
// Container dạng card hiện đại với glassmorphism và viền phản quang

struct ZevCard<Content: View>: View {
    var padding: CGFloat = ZevTheme.Spacing.md
    var cornerRadius: CGFloat = ZevTheme.Radius.lg
    var borderGlow: Bool = false
    let content: Content
    
    init(
        padding: CGFloat = ZevTheme.Spacing.md,
        cornerRadius: CGFloat = ZevTheme.Radius.lg,
        borderGlow: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.borderGlow = borderGlow
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(ZevTheme.Colors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        borderGlow ? ZevTheme.Colors.primary.opacity(0.35) : ZevTheme.Colors.border,
                        lineWidth: 1
                    )
            )
            .shadow(color: borderGlow ? ZevTheme.Shadow.glow : Color.black.opacity(0.05), radius: borderGlow ? 10 : 6, x: 0, y: 3)
    }
}

// MARK: - ZevButton
// Nút bấm hiện đại hỗ trợ kiểu dáng gradient, outline, secondary, loading indicator

struct ZevButton: View {
    enum Style {
        case primary
        case secondary
        case outline
        case danger
    }
    
    let title: String
    var icon: String? = nil
    var style: Style = .primary
    var isLoading: Bool = false
    var isFullWidth: Bool = true
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            guard !isLoading else { return }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                }
                
                Text(title)
                    .font(ZevTheme.Typography.heading(15))
            }
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .frame(height: 50)
            .padding(.horizontal, 20)
            .background(buttonBackground)
            .foregroundColor(buttonForegroundColor)
            .cornerRadius(ZevTheme.Radius.md)
            .overlay(buttonBorder)
            .shadow(color: shadowColor, radius: 8, x: 0, y: 4)
            .opacity(isLoading ? 0.75 : 1.0)
        }
        .disabled(isLoading)
    }
    
    @ViewBuilder
    private var buttonBackground: some View {
        switch style {
        case .primary:
            ZevTheme.Gradients.primary
        case .secondary:
            ZevTheme.Colors.surface2
        case .outline:
            Color.clear
        case .danger:
            ZevTheme.Colors.danger
        }
    }
    
    @ViewBuilder
    private var buttonBorder: some View {
        switch style {
        case .outline:
            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                .stroke(ZevTheme.Colors.border, lineWidth: 1.5)
        case .primary:
            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        default:
            EmptyView()
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .primary: return ZevTheme.Colors.primary.opacity(0.35)
        case .danger:  return ZevTheme.Colors.danger.opacity(0.3)
        default:       return Color.clear
        }
    }

    private var buttonForegroundColor: Color {
        switch style {
        case .primary, .danger: return .white
        case .secondary, .outline: return ZevTheme.Colors.text
        }
    }
}

// MARK: - StatusBadge
// Huy hiệu trạng thái với màu sắc tương ứng

struct StatusBadge: View {
    let title: String
    var color: Color = ZevTheme.Colors.primary
    var isPill: Bool = true
    
    var body: some View {
        Text(title)
            .font(ZevTheme.Typography.caption(11))
            .fontWeight(.semibold)
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.16))
            .cornerRadius(isPill ? ZevTheme.Radius.full : ZevTheme.Radius.sm)
            .overlay(
                RoundedRectangle(cornerRadius: isPill ? ZevTheme.Radius.full : ZevTheme.Radius.sm)
                    .stroke(color.opacity(0.3), lineWidth: 0.8)
            )
    }
}

// MARK: - SectionHeader
// Tiêu đề phân đoạn trang

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    var body: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ZevTheme.Typography.heading(18))
                    .foregroundColor(ZevTheme.Colors.text)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(ZevTheme.Typography.caption(12))
                        .foregroundColor(ZevTheme.Colors.textMuted)
                }
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(ZevTheme.Typography.caption(13))
                        .foregroundColor(ZevTheme.Colors.primary)
                }
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - DeviceChip
// Chip nhỏ hiển thị thông tin thiết bị đang kết nối

struct DeviceChip: View {
    let modelName: String
    let iosVersion: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "iphone")
                .font(.system(size: 12))
                .foregroundColor(ZevTheme.Colors.primary)
            
            Text("\(modelName) • iOS \(iosVersion)")
                .font(ZevTheme.Typography.caption(12))
                .foregroundColor(ZevTheme.Colors.textMuted)
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

// MARK: - ZevCachedImage
// Tải ảnh tức thì: ưu tiên ảnh local trong Bundle/Disk -> sau đó mới tải từ URL

struct ZevCachedImage: View {
    let urlString: String?
    let fallbackSystemIcon: String
    var width: CGFloat = 40
    var height: CGFloat = 40
    var cornerRadius: CGFloat = 8
    
    var body: some View {
        Group {
            if let localImage = findLocalImage() {
                Image(uiImage: localImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else if let urlStr = urlString, let validURL = URL(string: urlStr), !urlStr.isEmpty {
                AsyncImage(url: validURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: width, height: height)
                            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    default:
                        placeholderIcon
                    }
                }
            } else {
                placeholderIcon
            }
        }
    }
    
    private var placeholderIcon: some View {
        Image(systemName: fallbackSystemIcon)
            .font(.system(size: min(width, height) * 0.5))
            .foregroundColor(ZevTheme.Colors.primary)
            .frame(width: width, height: height)
    }
    
    private func findLocalImage() -> UIImage? {
        guard let urlString = urlString, !urlString.isEmpty else { return nil }
        
        let filename = (urlString as NSString).lastPathComponent
        let nameWithoutExt = ((filename as NSString).deletingPathExtension).lowercased()
        
        // 1. Kiểm tra Assets
        if let img = UIImage(named: filename) ?? UIImage(named: nameWithoutExt) {
            return img
        }
        
        // 2. Kiểm tra trong Bundle Root hoặc Images/
        let possiblePaths = [
            Bundle.main.path(forResource: nameWithoutExt, ofType: "png"),
            Bundle.main.path(forResource: filename, ofType: nil),
            Bundle.main.path(forResource: "Images/\(filename)", ofType: nil),
            Bundle.main.path(forResource: "Images/\(nameWithoutExt)", ofType: "png")
        ]
        
        for path in possiblePaths {
            if let p = path, let img = UIImage(contentsOfFile: p) {
                return img
            }
        }
        
        return nil
    }
}

