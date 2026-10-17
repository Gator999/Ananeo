import CoreLocation
import Foundation
import Observation

/// One-shot, when-in-use location. Good enough for a neighborhood feed, and it keeps battery use low.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    enum Status: Equatable {
        case needsPermission
        case denied
        case locating
        case ready(CLLocationCoordinate2D)
    }

    private(set) var authorization: CLAuthorizationStatus
    private(set) var coordinate: CLLocationCoordinate2D?
    private(set) var errorMessage: String?

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var status: Status {
        switch authorization {
        case .notDetermined: return .needsPermission
        case .denied, .restricted: return .denied
        default: return coordinate.map(Status.ready) ?? .locating
        }
    }

    /// Asks for permission the first time, otherwise refreshes the location.
    func request() {
        errorMessage = nil
        switch authorization {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        default:
            break
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorization = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                self.manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last?.coordinate else { return }
        Task { @MainActor in coordinate = latest }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        let message = error.localizedDescription
        Task { @MainActor in errorMessage = message }
    }
}

extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
