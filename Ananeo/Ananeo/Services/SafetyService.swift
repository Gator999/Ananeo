import Foundation
import Observation
import Supabase

/// Reports, blocks, and moderation.
@MainActor
@Observable
final class SafetyService {
    /// People the signed-in user has blocked, most recent first.
    private(set) var blocked: [BlockedPerson] = []
    private(set) var isModerator = false
    /// Bumped when blocks change, so feeds and pickups know to reload.
    private(set) var revision = 0

    @ObservationIgnored private let client: SupabaseClient

    init(client: SupabaseClient = Backend.client) {
        self.client = client
    }

    func isBlocked(_ userID: UUID) -> Bool {
        blocked.contains { $0.id == userID }
    }

    /// Forgets everything, for when the signed-in account changes.
    func reset() {
        blocked = []
        isModerator = false
    }

    // MARK: - Blocks

    private struct BlockRow: Decodable {
        struct Profile: Decodable {
            let display_name: String
        }

        let blocked_id: UUID
        let created_at: Date
        let profile: Profile?
    }

    func refresh() async throws {
        let rows: [BlockRow] = try await client.from("blocks")
            .select("blocked_id, created_at, profile:profiles!blocks_blocked_id_fkey(display_name)")
            .order("created_at", ascending: false)
            .execute()
            .value
        blocked = rows.map { BlockedPerson(id: $0.blocked_id, name: $0.profile?.display_name ?? "Neighbor", blockedAt: $0.created_at) }
        isModerator = try await client.rpc("is_moderator").execute().value
    }

    /// Hides each person's listings and messages from the other, and ends any pickup in progress
    /// between them.
    func block(_ userID: UUID) async throws {
        do {
            try await client.from("blocks").insert(["blocked_id": userID]).execute()
        } catch let error as PostgrestError where error.code == "23505" {
            // Already blocked.
        }
        await changed()
    }

    func unblock(_ userID: UUID) async throws {
        try await client.from("blocks").delete().eq("blocked_id", value: userID).execute()
        await changed()
    }

    /// The write already succeeded, so a failed reload only leaves the list stale until the next refresh.
    private func changed() async {
        revision += 1
        try? await refresh()
    }

    // MARK: - Reports

    private struct NewReport: Encodable {
        let target_type: String
        let target_id: UUID
        let reason: String
    }

    func report(_ target: ReportTarget, reason: ReportReason, details: String) async throws {
        let details = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let text = details.isEmpty ? reason.title : "\(reason.title): \(details)"
        do {
            try await client.from("reports")
                .insert(NewReport(target_type: target.kind.rawValue, target_id: target.id, reason: String(text.prefix(1000))))
                .execute()
        } catch let error as PostgrestError where error.code == "23505" {
            // Already reported. Once is enough.
        }
    }

    // MARK: - Moderation

    func moderationQueue() async throws -> [ModerationCase] {
        try await client.rpc("moderation_queue").execute().value
    }

    private struct ModerateParams: Encodable {
        let p_target_type: String
        let p_target_id: UUID
        let p_action: String
    }

    func moderate(_ moderationCase: ModerationCase, _ action: ModerationAction) async throws {
        try await client.rpc("moderate", params: ModerateParams(
            p_target_type: moderationCase.targetType.rawValue,
            p_target_id: moderationCase.targetID,
            p_action: action.rawValue
        )).execute()
    }
}
