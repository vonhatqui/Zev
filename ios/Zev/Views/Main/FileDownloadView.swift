import SwiftUI

// MARK: - FileDownloadItem
// Model hiển thị cho danh sách file tải về

struct DownloadableFileItem: Identifiable {
    let id: Int
    let title: String
    let description: String
    let gameName: String
    let version: String
    let sizeText: String
    let fileExt: String
    let isVipOnly: Bool
}

// MARK: - FileDownloadView
// Giao diện quản lý và tải xuống file dylib, config, patch bảo mật

struct FileDownloadView: View {
    @State private var files: [DownloadableFileItem] = [
        DownloadableFileItem(
            id: 1,
            title: "Free Fire Mod Menu V1",
            description: "Menu hỗ trợ định vị mục tiêu, giảm giật và tối ưu khung hình FPS.",
            gameName: "Free Fire",
            version: "v1.4",
            sizeText: "12.8 MB",
            fileExt: "dylib",
            isVipOnly: true
        ),
        DownloadableFileItem(
            id: 2,
            title: "PUBG Mobile Anti-Shake Config",
            description: "Cấu hình cân bằng con quay hồi chuyển Gyroscope và khử rung.",
            gameName: "PUBG Mobile",
            version: "v2.1",
            sizeText: "3.2 MB",
            fileExt: "json",
            isVipOnly: true
        ),
        DownloadableFileItem(
            id: 3,
            title: "Liên Quân Map Hack Dylib",
            description: "Hỗ trợ tầm nhìn rộng, hiển thị hồi chiêu và rừng đối phương.",
            gameName: "Liên Quân Mobile",
            version: "v1.0",
            sizeText: "8.5 MB",
            fileExt: "dylib",
            isVipOnly: true
        ),
        DownloadableFileItem(
            id: 4,
            title: "Zev Global Optimization Script",
            description: "Tập lệnh giải phóng bộ nhớ RAM và tối ưu CPU khi chơi game nặng.",
            gameName: "Hệ thống chung",
            version: "v3.0",
            sizeText: "1.1 MB",
            fileExt: "plist",
            isVipOnly: false
        )
    ]
    
    @State private var searchQuery: String = ""
    @State private var downloadingFileId: Int? = nil
    @State private var downloadSuccessMessage: String? = nil
    @State private var downloadErrorMessage: String? = nil
    
    var filteredFiles: [DownloadableFileItem] {
        if searchQuery.isEmpty {
            return files
        } else {
            return files.filter {
                $0.title.localizedCaseInsensitiveContains(searchQuery) ||
                $0.gameName.localizedCaseInsensitiveContains(searchQuery) ||
                $0.fileExt.localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                ZevTheme.Colors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 16) {
                    // Header & Search
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Tải File & Cấu Hình")
                                    .font(ZevTheme.Typography.title(22))
                                    .foregroundColor(ZevTheme.Colors.text)
                                Text("Tải file dylib, mod và config thông qua Token bảo mật")
                                    .font(ZevTheme.Typography.caption(12))
                                    .foregroundColor(ZevTheme.Colors.textMuted)
                            }
                            Spacer()
                        }
                        
                        // Search Bar
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(ZevTheme.Colors.textMuted)
                            
                            TextField("Tìm kiếm file, game, đuôi file...", text: $searchQuery)
                                .font(ZevTheme.Typography.body(14))
                                .foregroundColor(ZevTheme.Colors.text)
                            
                            if !searchQuery.isEmpty {
                                Button(action: { searchQuery = "" }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(ZevTheme.Colors.textDim)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(ZevTheme.Colors.surface2)
                        .cornerRadius(ZevTheme.Radius.md)
                        .overlay(
                            RoundedRectangle(cornerRadius: ZevTheme.Radius.md)
                                .stroke(ZevTheme.Colors.border, lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Alert Messages
                    if let msg = downloadSuccessMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(ZevTheme.Colors.success)
                            Text(msg)
                                .font(ZevTheme.Typography.caption(12))
                                .foregroundColor(ZevTheme.Colors.success)
                            Spacer()
                            Button(action: { downloadSuccessMessage = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(ZevTheme.Colors.textMuted)
                            }
                        }
                        .padding(12)
                        .background(ZevTheme.Colors.success.opacity(0.12))
                        .cornerRadius(ZevTheme.Radius.md)
                        .padding(.horizontal, 16)
                    }
                    
                    if let err = downloadErrorMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(ZevTheme.Colors.danger)
                            Text(err)
                                .font(ZevTheme.Typography.caption(12))
                                .foregroundColor(ZevTheme.Colors.danger)
                            Spacer()
                            Button(action: { downloadErrorMessage = nil }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 11))
                                    .foregroundColor(ZevTheme.Colors.textMuted)
                            }
                        }
                        .padding(12)
                        .background(ZevTheme.Colors.danger.opacity(0.12))
                        .cornerRadius(ZevTheme.Radius.md)
                        .padding(.horizontal, 16)
                    }
                    
                    // File List
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredFiles) { file in
                                fileCard(file)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    // MARK: - File Card
    private func fileCard(_ file: DownloadableFileItem) -> some View {
        ZevCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    
                    // File Ext Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(ZevTheme.Colors.surface3)
                            .frame(width: 46, height: 46)
                        
                        Text(file.fileExt.uppercased())
                            .font(ZevTheme.Typography.caption(11))
                            .fontWeight(.bold)
                            .foregroundColor(ZevTheme.Colors.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(file.title)
                                .font(ZevTheme.Typography.heading(15))
                                .foregroundColor(ZevTheme.Colors.text)
                            
                            Spacer()
                            
                            if file.isVipOnly {
                                StatusBadge(title: "VIP Key", color: ZevTheme.Colors.warning)
                            } else {
                                StatusBadge(title: "Miễn phí", color: ZevTheme.Colors.success)
                            }
                        }
                        
                        Text(file.description)
                            .font(ZevTheme.Typography.caption(12))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                            .lineLimit(2)
                    }
                }
                
                Divider().background(ZevTheme.Colors.border)
                
                // Meta Info & Download Action
                HStack {
                    HStack(spacing: 12) {
                        Text(file.gameName)
                            .font(ZevTheme.Typography.caption(11))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        
                        Text("•")
                            .font(ZevTheme.Typography.caption(11))
                            .foregroundColor(ZevTheme.Colors.border)
                        
                        Text(file.version)
                            .font(ZevTheme.Typography.mono(11))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                        
                        Text("•")
                            .font(ZevTheme.Typography.caption(11))
                            .foregroundColor(ZevTheme.Colors.border)
                        
                        Text(file.sizeText)
                            .font(ZevTheme.Typography.caption(11))
                            .foregroundColor(ZevTheme.Colors.textMuted)
                    }
                    
                    Spacer()
                    
                    // Download Button
                    Button(action: {
                        startDownload(file)
                    }) {
                        HStack(spacing: 6) {
                            if downloadingFileId == file.id {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "arrow.down.to.line")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            
                            Text("Tải Về")
                                .font(ZevTheme.Typography.caption(12))
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(ZevTheme.Gradients.primary)
                        .cornerRadius(ZevTheme.Radius.md)
                        .shadow(color: ZevTheme.Colors.primary.opacity(0.3), radius: 6, y: 3)
                    }
                    .disabled(downloadingFileId != nil)
                }
            }
        }
    }
    
    // MARK: - Download Action
    private func startDownload(_ file: DownloadableFileItem) {
        downloadingFileId = file.id
        downloadSuccessMessage = nil
        downloadErrorMessage = nil
        
        Task {
            do {
                let tokenResult = try await APIService.shared.requestDownloadToken(fileId: file.id)
                
                if let url = URL(string: tokenResult.downloadUrl) {
                    await MainActor.run {
                        UIApplication.shared.open(url)
                        downloadSuccessMessage = "Đã khởi tạo link tải bảo mật cho: \(file.title)"
                        downloadingFileId = nil
                    }
                } else {
                    await MainActor.run {
                        downloadErrorMessage = "Đường dẫn tải file không hợp lệ."
                        downloadingFileId = nil
                    }
                }
            } catch {
                await MainActor.run {
                    downloadErrorMessage = "Lỗi khi lấy link tải: \(error.localizedDescription)"
                    downloadingFileId = nil
                }
            }
        }
    }
}
