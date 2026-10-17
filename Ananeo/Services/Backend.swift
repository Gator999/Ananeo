import Foundation
import Supabase

/// Shared Supabase client. URL and key come from Config/Ananeo.xcconfig via Info.plist.
enum Backend {
    static let url: URL = {
        guard let string = Bundle.main.infoDictionary?["SupabaseURL"] as? String, let url = URL(string: string) else {
            fatalError("SupabaseURL missing from Info.plist. See Config/Ananeo.xcconfig.")
        }
        return url
    }()

    /// True when pointed at the local `supabase start` stack.
    static var isLocal: Bool { ["127.0.0.1", "localhost"].contains(url.host() ?? "") }

    static let client: SupabaseClient = {
        guard let key = Bundle.main.infoDictionary?["SupabaseKey"] as? String, !key.isEmpty else {
            fatalError("SupabaseKey missing from Info.plist. See Config/Ananeo.xcconfig.")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
        )
    }()
}
