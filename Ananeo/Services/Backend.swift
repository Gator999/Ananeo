import Foundation
import Supabase

/// Shared Supabase client. URL and key come from Config/Ananeo.xcconfig via Info.plist.
enum Backend {
    static let client: SupabaseClient = {
        let info = Bundle.main.infoDictionary ?? [:]
        guard
            let urlString = info["SupabaseURL"] as? String,
            let url = URL(string: urlString),
            let key = info["SupabaseKey"] as? String,
            !key.isEmpty
        else {
            fatalError("SupabaseURL or SupabaseKey missing from Info.plist. See Config/Ananeo.xcconfig.")
        }
        return SupabaseClient(
            supabaseURL: url,
            supabaseKey: key,
            options: .init(auth: .init(emitLocalSessionAsInitialSession: true))
        )
    }()
}
