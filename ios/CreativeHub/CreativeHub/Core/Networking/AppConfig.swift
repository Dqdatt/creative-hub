import Foundation

struct AppConfig: Equatable {
    var supabaseURL: URL?
    var supabaseAnonKey: String
    var bundleIdentifier: String

    var isSupabaseConfigured: Bool {
        supabaseURL != nil && !supabaseAnonKey.isEmpty && !supabaseAnonKey.contains("your-supabase")
    }

    static let current = AppConfig(
        supabaseURL: Bundle.main.infoDictionary?["SUPABASE_URL"].flatMap { URL(string: "\($0)") },
        supabaseAnonKey: Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? "",
        bundleIdentifier: Bundle.main.bundleIdentifier ?? ""
    )
}
