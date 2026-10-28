import SwiftUI

// MARK: - AuthViewModel
// Quản lý logic kích hoạt bản quyền, kiểm tra tính hợp lệ và thông báo lỗi

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var keyCode: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isSuccess: Bool = false
    
    private let appState = AppStateManager.shared
    
    func activate() async {
        let cleanKey = keyCode.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !cleanKey.isEmpty else {
            errorMessage = "Vui lòng nhập mã bản quyền."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let result = try await APIService.shared.verifyKey(cleanKey)
            appState.activateKey(cleanKey, result: result)
            isSuccess = true
        } catch let apiError as APIError {
            errorMessage = apiError.localizedDescription
        } catch {
            errorMessage = "Lỗi kết nối máy chủ: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
}
