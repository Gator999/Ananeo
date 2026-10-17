import Foundation

/// The database works in kilometers. The app shows miles.
enum Distance {
    static let kmPerMile = 1.609344

    static func miles(fromKm km: Double) -> Double { km / kmPerMile }
    static func km(fromMiles miles: Double) -> Double { miles * kmPerMile }

    /// Listing locations are fuzzed by up to a quarter mile, so short distances read as approximate.
    static func label(miles: Double) -> String {
        if miles < 0.3 { return "Under ¼ mi" }
        if miles < 10 { return String(format: "About %.1f mi", miles) }
        return String(format: "About %.0f mi", miles)
    }
}
