import Foundation

enum AppError: LocalizedError, Equatable {
    case config(String)
    case auth(String)
    case permissionDenied
    case validation(String)
    case network
    case notFound(String)
    case backend(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .config(let message), .auth(let message), .validation(let message), .notFound(let message), .backend(let message), .unknown(let message):
            message
        case .permissionDenied:
            "Bạn không có quyền thực hiện thao tác này."
        case .network:
            "Không thể kết nối máy chủ. Vui lòng kiểm tra mạng."
        }
    }

    static func map(_ error: Error, fallback: String = "Không thể xử lý yêu cầu. Vui lòng thử lại.") -> AppError {
        if let appError = error as? AppError { return appError }
        if let configError = error as? AppConfigError {
            return .config(configError.localizedDescription)
        }

        let rawMessage = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let message = rawMessage.isEmpty ? fallback : rawMessage
        let lower = message.lowercased()

        if lower.contains("invalid login credentials") {
            return .auth("Email hoặc mật khẩu chưa đúng.")
        }
        if lower.contains("email not confirmed") {
            return .auth("Email chưa được xác nhận. Vui lòng kiểm tra hộp thư.")
        }
        if lower.contains("rate limit") {
            return .auth("Bạn thao tác quá nhanh. Vui lòng thử lại sau ít phút.")
        }
        if lower.contains("failed to fetch") || lower.contains("network") || lower.contains("offline") {
            return .network
        }
        if lower.contains("row-level security") || lower.contains("permission denied") || lower.contains("42501") {
            return .permissionDenied
        }

        return .backend(message)
    }
}

