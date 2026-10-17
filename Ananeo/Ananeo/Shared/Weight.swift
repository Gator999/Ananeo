import Foundation

/// The database works in kilograms. The app shows pounds, like the website.
enum Weight {
    static let lbPerKg = 2.20462262185

    static func pounds(fromKg kg: Double) -> Double { kg * lbPerKg }
    static func kg(fromPounds pounds: Double) -> Double { pounds / lbPerKg }
}
