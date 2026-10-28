import SwiftUI

// MARK: - FileViewModel
// Quản lý yêu cầu token tải file và metadata

@MainActor
final class FileViewModel: ObservableObject {
    @Published var isLoading: Bool = false
    @Published var downloadToken: DownloadTokenResponse? = nil
    @Published var errorMessage: String? = nil
    
    func requestDownload(fileId: Int) async -> URL? {
        isLoading = true
        errorMessage = nil
        
        do {
            let res = try await APIService.shared.requestDownloadToken(fileId: fileId)
            downloadToken = res
            isLoading = false
            return URL(string: res.downloadUrl)
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return nil
        }
    }
}
