import Foundation

struct AppConfig: Equatable {
    let supabaseURL: URL
    let supabaseAnonKey: String

    static func current(bundle: Bundle = .main) throws -> AppConfig {
        let urlString = bundle.object(forInfoDictionaryKey: "SupabaseURL") as? String
        let anonKey = bundle.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String
        return try AppConfig(urlString: urlString, anonKey: anonKey)
    }

    init(urlString: String?, anonKey: String?) throws {
        let normalizedURL = (urlString ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKey = (anonKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        guard !Self.isPlaceholder(normalizedURL), !Self.isPlaceholder(normalizedKey) else {
            throw AppConfigError.missingSupabaseConfig
        }

        guard let url = URL(string: normalizedURL), url.scheme == "https", url.host != nil else {
            throw AppConfigError.invalidSupabaseURL
        }

        supabaseURL = url
        supabaseAnonKey = normalizedKey
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        value.isEmpty ||
            value.contains("$(") ||
            value.localizedCaseInsensitiveContains("your-project-ref") ||
            value.localizedCaseInsensitiveContains("your-supabase") ||
            value.localizedCaseInsensitiveContains("anon-or-publishable")
    }
}

enum AppConfigError: LocalizedError, Equatable {
    case missingSupabaseConfig
    case invalidSupabaseURL

    var errorDescription: String? {
        switch self {
        case .missingSupabaseConfig:
            "Thiếu cấu hình Supabase URL hoặc anon/publishable key."
        case .invalidSupabaseURL:
            "Supabase URL không hợp lệ. URL phải dùng HTTPS."
        }
    }
}
