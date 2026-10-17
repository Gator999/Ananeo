import CoreLocation
import Foundation
import Observation
import Supabase

/// Reads the places map: donation centers, repair cafés, e-waste drop-offs, and textile bins near a point.
@MainActor
@Observable
final class PlaceService {
    @ObservationIgnored private let client: SupabaseClient

    init(client: SupabaseClient = Backend.client) {
        self.client = client
    }

    private struct NearbyParams: Encodable {
        let lat: Double
        let lng: Double
        let radius_km: Double
        let only_kind: String?
        let max_results: Int
    }

    func nearby(_ coordinate: CLLocationCoordinate2D, radiusMiles: Double, kind: PlaceKind? = nil) async throws -> [Place] {
        try await client
            .rpc("nearby_places", params: NearbyParams(
                lat: coordinate.latitude,
                lng: coordinate.longitude,
                radius_km: Distance.km(fromMiles: radiusMiles),
                only_kind: kind?.rawValue,
                max_results: 100
            ))
            .execute()
            .value
    }
}
