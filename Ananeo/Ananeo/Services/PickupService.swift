import Foundation
import Observation
import Supabase

/// Pickup requests, reservations, and two-sided handoff confirmation.
/// Keeps the signed-in user's pickups so the tab, its detail screens, and listing pages agree.
@MainActor
@Observable
final class PickupService {
    private(set) var all: [Pickup] = []
    private(set) var hasLoaded = false
    /// Bumped after any change so impact totals know to reload.
    private(set) var revision = 0

    @ObservationIgnored private let client: SupabaseClient

    init(client: SupabaseClient = Backend.client) {
        self.client = client
    }

    /// Pickups where the next step is the signed-in user's.
    var needsYouCount: Int { all.filter(\.needsYou).count }

    func pickup(for itemID: UUID) -> Pickup? {
        all.first { $0.id == itemID }
    }

    // MARK: - Reading

    /// One row per request, as returned by `my_pickups`.
    private struct Row: Decodable {
        let request_id: UUID
        let item_id: UUID
        let title: String
        let category: ItemCategory
        let photo: String?
        let item_status: ItemStatus
        let is_giver: Bool
        let other_user_id: UUID
        let other_name: String
        let requested_at: Date
        let handoff_id: UUID?
        let confirmed_by_me: Bool
        let confirmed_by_them: Bool
        let completed_at: Date?
        let unread_count: Int
        let last_message: String?
        let last_message_mine: Bool?
    }

    func refresh() async throws {
        let rows: [Row] = try await client.rpc("my_pickups").execute().value
        all = Self.group(rows)
        hasLoaded = true
    }

    /// Forgets everything, for when the signed-in account changes.
    func reset() {
        all = []
        hasLoaded = false
    }

    /// For SwiftUI previews.
    static func preview(_ pickups: [Pickup]) -> PickupService {
        let service = PickupService()
        service.all = pickups
        service.hasLoaded = true
        return service
    }

    /// Groups rows by item, keeping the server's most-recent-first order.
    private static func group(_ rows: [Row]) -> [Pickup] {
        var order: [UUID] = []
        var byItem: [UUID: [Row]] = [:]
        for row in rows {
            if byItem[row.item_id] == nil { order.append(row.item_id) }
            byItem[row.item_id, default: []].append(row)
        }
        return order.compactMap { itemID in
            guard let rows = byItem[itemID], let first = rows.first else { return nil }
            let requests = rows.map { row in
                PickupRequest(
                    id: row.request_id,
                    otherUserID: row.other_user_id,
                    otherName: row.other_name,
                    requestedAt: row.requested_at,
                    handoff: row.handoff_id.map {
                        Handoff(id: $0, confirmedByMe: row.confirmed_by_me, confirmedByThem: row.confirmed_by_them, completedAt: row.completed_at)
                    },
                    unreadCount: row.unread_count,
                    lastMessage: row.last_message,
                    lastMessageIsMine: row.last_message_mine ?? false
                )
            }
            return Pickup(
                id: itemID,
                title: first.title,
                category: first.category,
                photo: first.photo,
                status: first.item_status,
                isGiver: first.is_giver,
                requests: requests.sorted { $0.requestedAt < $1.requestedAt }
            )
        }
    }

    // MARK: - Getting

    private struct NewRequest: Encodable {
        let item_id: UUID
        let giver_id: UUID
    }

    struct UnavailableError: LocalizedError {
        var errorDescription: String? { "This item is no longer available." }
    }

    private struct RequestID: Decodable {
        let id: UUID
    }

    /// Asks the owner for an item and returns the request, which is also the chat about it.
    /// Asking twice is harmless.
    @discardableResult
    func request(_ listing: Listing) async throws -> UUID {
        let request: RequestID
        do {
            request = try await client.from("conversations")
                .insert(NewRequest(item_id: listing.id, giver_id: listing.ownerID), returning: .representation)
                .select("id")
                .single()
                .execute()
                .value
        } catch let error as PostgrestError where error.code == "23505" {
            // Already asked, maybe from another device.
            let userID = try await client.auth.session.user.id
            request = try await client.from("conversations")
                .select("id")
                .eq("item_id", value: listing.id)
                .eq("receiver_id", value: userID)
                .single()
                .execute()
                .value
        } catch let error as PostgrestError where error.code == "42501" {
            // Reserved or taken down since the feed loaded.
            throw UnavailableError()
        }
        await changed()
        return request.id
    }

    /// Withdraws a request. If the item was reserved for you, the giver can choose someone else.
    func withdraw(_ pickup: Pickup) async throws {
        try await client.rpc("withdraw_request", params: ["p_item_id": pickup.id]).execute()
        await changed()
    }

    // MARK: - Giving

    /// Reserves the item for one person. It leaves the Browse feed until the handoff or a cancel.
    func reserve(_ pickup: Pickup, for request: PickupRequest) async throws {
        try await client.rpc("reserve_item", params: ["p_item_id": pickup.id, "p_receiver_id": request.otherUserID]).execute()
        await changed()
    }

    /// Makes the item available again. Everyone's requests stay open.
    func cancelReservation(_ pickup: Pickup) async throws {
        try await client.rpc("cancel_reservation", params: ["p_item_id": pickup.id]).execute()
        await changed()
    }

    // MARK: - Both sides

    /// Confirms your half of the handoff. Once both people confirm, the item counts toward impact.
    func confirm(_ handoff: Handoff) async throws {
        try await client.rpc("confirm_handoff", params: ["p_handoff_id": handoff.id]).execute()
        await changed()
    }

    /// The write already succeeded, so a failed reload only leaves the list stale until the next refresh.
    private func changed() async {
        revision += 1
        try? await refresh()
    }
}
