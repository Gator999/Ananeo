import Foundation
import Observation
import Supabase

/// Whether the signed-in person has accepted the current terms of use. Acceptance is recorded on
/// the server and remembered on the device, so later launches don't wait on the network.
@MainActor
@Observable
final class TermsService {
    enum Status: Equatable {
        case checking
        case needed
        case accepted
        case failed(String)
    }

    private(set) var status: Status = .checking

    @ObservationIgnored private let client: SupabaseClient
    @ObservationIgnored private let defaults: UserDefaults

    init(client: SupabaseClient = Backend.client, defaults: UserDefaults = .standard) {
        self.client = client
        self.defaults = defaults
    }

    /// Runs while the status is `.checking`.
    func check(userID: UUID) async {
        if rememberedVersion(for: userID) >= TermsOfUse.version {
            status = .accepted
            return
        }
        do {
            let version: Int = try await client.rpc("my_terms_version").execute().value
            remember(version, for: userID)
            status = version >= TermsOfUse.version ? .accepted : .needed
        } catch is CancellationError {
        } catch {
            status = .failed(error.localizedDescription)
        }
    }

    func accept(userID: UUID) async throws {
        try await client.rpc("accept_terms", params: ["p_version": TermsOfUse.version]).execute()
        remember(TermsOfUse.version, for: userID)
        status = .accepted
    }

    /// Starts over, for a retry or when the signed-in account changes.
    func reset() {
        status = .checking
    }

    private func key(for userID: UUID) -> String {
        "acceptedTermsVersion.\(userID.uuidString)"
    }

    private func rememberedVersion(for userID: UUID) -> Int {
        defaults.integer(forKey: key(for: userID))
    }

    private func remember(_ version: Int, for userID: UUID) {
        defaults.set(version, forKey: key(for: userID))
    }
}
