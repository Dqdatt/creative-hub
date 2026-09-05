import Foundation

enum ProfileRoleDisplay {
    static func label(for role: CreativeHubRole) -> String {
        switch role {
        case .admin:
            "Admin"
        case .creativeManager:
            "Manager"
        case .contentCreator:
            "Creator"
        case .editor:
            "Editor"
        }
    }
}

struct UserProfile: Equatable, Sendable {
    var id: UUID
    var email: String
    var fullName: String
    var displayName: String
    var shortName: String?
    var phone: String
    var department: String
    var role: CreativeHubRole
    var rawRole: String?
    var avatarURL: URL?
    var editorCode: String?
    var isEditorMember: Bool
    var isActive: Bool

    var roleLabel: String {
        ProfileRoleDisplay.label(for: role)
    }

    var statusLabel: String {
        isActive ? "Đang hoạt động" : "Tạm khóa"
    }

    var displayIdentity: String {
        displayName.profileNonEmpty ?? fullName.profileNonEmpty ?? email
    }

    var initials: String {
        ProfileInitials.make(from: displayIdentity)
    }

    var editorIdentityLabel: String? {
        guard isEditorMember else { return nil }
        if let code = editorCode?.profileNonEmpty {
            return "Editor: \(code)"
        }
        return "Editor"
    }
}

struct ProfileDraft: Equatable, Sendable {
    var fullName: String
    var displayName: String
    var phone: String
    var department: String

    init(fullName: String, displayName: String, phone: String, department: String) {
        self.fullName = fullName
        self.displayName = displayName
        self.phone = phone
        self.department = department
    }

    init(profile: UserProfile) {
        fullName = profile.fullName
        displayName = profile.displayName
        phone = profile.phone
        department = profile.department
    }
}

struct PasswordDraft: Equatable, Sendable {
    var currentPassword = ""
    var newPassword = ""
    var confirmPassword = ""
}

enum ProfileValidation {
    static func validate(_ draft: ProfileDraft) -> String? {
        if draft.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Vui lòng nhập họ tên."
        }
        if draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Vui lòng nhập tên hiển thị."
        }
        let phone = draft.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        if !phone.isEmpty {
            let pattern = #"^[0-9+\s().-]{8,18}$"#
            if phone.range(of: pattern, options: .regularExpression) == nil {
                return "Số điện thoại chưa đúng định dạng."
            }
        }
        return nil
    }

    static func validatePassword(current: String, next: String, confirm: String) -> String? {
        if current.isEmpty || next.isEmpty || confirm.isEmpty {
            return "Vui lòng nhập đầy đủ thông tin mật khẩu."
        }
        if next.count < 8 {
            return "Mật khẩu mới cần tối thiểu 8 ký tự."
        }
        if next == current {
            return "Mật khẩu mới cần khác mật khẩu hiện tại."
        }
        if next != confirm {
            return "Xác nhận mật khẩu mới chưa khớp."
        }
        return nil
    }
}

enum ProfileInitials {
    static func make(from name: String) -> String {
        let parts = name
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { !$0.isEmpty }
        if parts.isEmpty { return "CH" }
        let initials = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "CH" : initials.uppercased()
    }
}

extension Optional where Wrapped == String {
    var profileNonEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

extension String {
    var profileNonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
