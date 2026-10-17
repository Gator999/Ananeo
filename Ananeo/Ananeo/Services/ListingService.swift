import CoreLocation
import Foundation
import Observation
import Supabase
import UIKit

/// Reads and writes listings and their photos.
@MainActor
@Observable
final class ListingService {
    static let bucket = "item-photos"
    static let maxPhotos = 5

    /// Bumped after any change so feeds know to reload.
    private(set) var revision = 0

    @ObservationIgnored private let client: SupabaseClient

    init(client: SupabaseClient = Backend.client) {
        self.client = client
    }

    // MARK: - Reading

    private struct NearbyParams: Encodable {
        let lat: Double
        let lng: Double
        let radius_km: Double
        let only_category: String?
        let max_results: Int
    }

    func nearby(_ coordinate: CLLocationCoordinate2D, radiusMiles: Double, category: ItemCategory?) async throws -> [Listing] {
        try await client
            .rpc("nearby_items", params: NearbyParams(
                lat: coordinate.latitude,
                lng: coordinate.longitude,
                radius_km: Distance.km(fromMiles: radiusMiles),
                only_category: category?.rawValue,
                max_results: 100
            ))
            .execute()
            .value
    }

    func photoURL(_ path: String) -> URL? {
        try? client.storage.from(Self.bucket).getPublicURL(path: path)
    }

    func myImpact() async throws -> Impact {
        let rows: [Impact] = try await client.rpc("my_impact").execute().value
        return rows.first ?? Impact()
    }

    func communityImpact() async throws -> CommunityImpact {
        let rows: [CommunityImpact] = try await client.rpc("community_impact").execute().value
        return rows.first ?? CommunityImpact()
    }

    // MARK: - Writing

    private struct NewItem: Encodable {
        let title: String
        let details: String
        let category: ItemCategory
        let condition: ItemCondition
        let mode: ItemMode
        let wants: String?
        /// Exact point as EWKT. The database fuzzes it before storing.
        let location: String
        let photos: [String]
    }

    /// Uploads photos, then creates the listing. If anything fails, uploaded photos are cleaned up.
    func create(_ draft: ListingDraft, photos: [Data], at coordinate: CLLocationCoordinate2D) async throws {
        // Storage policies compare against auth.uid()::text, which is lowercase.
        let folder = try await client.auth.session.user.id.uuidString.lowercased()
        let storage = client.storage.from(Self.bucket)
        var uploaded: [String] = []

        do {
            for data in photos.prefix(Self.maxPhotos) {
                let path = "\(folder)/\(UUID().uuidString.lowercased()).jpg"
                try await storage.upload(path, data: data, options: FileOptions(contentType: "image/jpeg"))
                uploaded.append(path)
            }

            let wants = draft.wants.trimmingCharacters(in: .whitespacesAndNewlines)
            try await client.from("items").insert(NewItem(
                title: draft.trimmedTitle,
                details: draft.details.trimmingCharacters(in: .whitespacesAndNewlines),
                category: draft.category,
                condition: draft.condition,
                mode: draft.mode,
                wants: draft.mode == .swap && !wants.isEmpty ? wants : nil,
                location: "SRID=4326;POINT(\(coordinate.longitude) \(coordinate.latitude))",
                photos: uploaded
            )).execute()
        } catch {
            if !uploaded.isEmpty {
                _ = try? await storage.remove(paths: uploaded)
            }
            throw error
        }
        revision += 1
    }

    /// Hides a listing from everyone. The row stays so history and impact remain intact.
    func remove(_ listing: Listing) async throws {
        try await client.from("items")
            .update(["status": ItemStatus.removed.rawValue])
            .eq("id", value: listing.id)
            .execute()
        revision += 1
    }

    // MARK: - Photos

    /// Converts any picked image to a JPEG no larger than 1600 px on its longest side.
    nonisolated static func preparePhoto(_ data: Data, maxDimension: CGFloat = 1600) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        let scale = min(1, maxDimension / longest)
        let size = CGSize(width: (image.size.width * scale).rounded(), height: (image.size.height * scale).rounded())
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}
