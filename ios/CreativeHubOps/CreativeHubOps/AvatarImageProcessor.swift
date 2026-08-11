import Foundation
import UIKit
import UniformTypeIdentifiers

enum AvatarImageProcessor {
    static let maxSourceBytes = 10 * 1024 * 1024
    static let maxDimension: CGFloat = 1024
    static let jpegQuality: CGFloat = 0.82
    static let outputContentType = "image/jpeg"

    static func cleanFileName(_ fileName: String) -> String {
        let lowercased = fileName.lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.")
        let scalars = lowercased.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let collapsed = String(scalars)
            .replacingOccurrences(of: #"-+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return collapsed.isEmpty ? "avatar.jpg" : collapsed
    }

    static func storagePath(userId: UUID, fileName: String, timestampMilliseconds: Int64) -> String {
        "\(userId.uuidString)/\(timestampMilliseconds)-\(cleanFileName(fileName))"
    }

    static func processedJPEGData(from sourceData: Data) throws -> Data {
        guard sourceData.count <= maxSourceBytes else {
            throw AppError.validation("Ảnh đại diện quá lớn.")
        }
        guard let image = UIImage(data: sourceData) else {
            throw AppError.validation("Định dạng ảnh chưa được hỗ trợ.")
        }

        let originalSize = image.size
        let maxSide = max(originalSize.width, originalSize.height)
        let scale = maxSide > maxDimension ? maxDimension / maxSide : 1
        let outputSize = CGSize(width: originalSize.width * scale, height: originalSize.height * scale)

        let renderer = UIGraphicsImageRenderer(size: outputSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: outputSize))
        }

        guard let data = resized.jpegData(compressionQuality: jpegQuality) else {
            throw AppError.validation("Không thể xử lý ảnh đại diện.")
        }
        return data
    }
}
