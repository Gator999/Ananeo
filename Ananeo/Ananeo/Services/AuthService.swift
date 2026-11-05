import AuthenticationServices
import CoreLocation
import CryptoKit
import Foundation
import Observation
import Supabase

/// Owns the signed-in state and the Sign in with Apple flow.
@MainActor
@Observable
final class AuthService {
    enum State: Equatable {
        case loading
        case signedOut
        case signedIn(userID: UUID)
    }

    private(set) var state: State = .loading
    private(set) var isWorking = false
    var errorMessage: String?
    /// Set for demo accounts (App Review), whose `app_metadata.demo_location` pins the app to one
    /// area so the seeded listings, places, and pickups show wherever the reviewer is.
    private(set) var demoCoordinate: CLLocationCoordinate2D?

    @ObservationIgnored private let client: SupabaseClient
    @ObservationIgnored private var currentNonce: String?
    @ObservationIgnored private var listener: Task<Void, Never>?

    init(client: SupabaseClient = Backend.client) {
        self.client = client
    }

    /// Starts listening for session changes. The stored session, if any, arrives first.
    func start() {
        guard listener == nil else { return }
        listener = Task { [weak self] in
            guard let self else { return }
            for await (_, session) in client.auth.authStateChanges {
                if let session, !session.isExpired {
                    demoCoordinate = Self.demoCoordinate(from: session.user.appMetadata)
                    state = .signedIn(userID: session.user.id)
                } else {
                    demoCoordinate = nil
                    state = .signedOut
                }
            }
        }
        #if DEBUG
        Task { await signInForLocalDevelopmentIfRequested() }
        #endif
    }

    #if DEBUG
    /// Local development only. scripts/dev-simulator.sh passes a test account through the
    /// environment so the simulator can run without an Apple ID. Ignored for hosted projects.
    private func signInForLocalDevelopmentIfRequested() async {
        let env = ProcessInfo.processInfo.environment
        guard Backend.isLocal,
              let email = env["ANANEO_DEV_EMAIL"],
              let password = env["ANANEO_DEV_PASSWORD"],
              client.auth.currentSession == nil
        else { return }
        do {
            try await client.auth.signIn(email: email, password: password)
        } catch {
            errorMessage = "Local dev sign-in failed: \(error.localizedDescription)"
        }
    }
    #endif

    // MARK: - Sign in with Apple

    /// Configures the Apple request. Apple receives a SHA-256 hash of the nonce, and Supabase
    /// receives the raw nonce, which lets Supabase verify the ID token was minted for this request.
    func prepare(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handle(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            errorMessage = error.localizedDescription

        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Apple didn't return a valid sign-in token. Please try again."
                return
            }

            isWorking = true
            defer { isWorking = false; currentNonce = nil }
            do {
                let session = try await client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
                )
                // Apple shares the name only on the very first sign-in, so save it right away.
                if let name = Self.displayName(from: credential.fullName) {
                    _ = try? await client.from("profiles")
                        .update(["display_name": name])
                        .eq("id", value: session.user.id)
                        .execute()
                }
            } catch {
                errorMessage = "Sign in failed: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Sign in with email

    /// Password sign-in for accounts created by hand, such as the App Review demo account.
    /// There is no sign-up form in the app, so everyone else uses Apple.
    func signIn(email: String, password: String) async -> Bool {
        errorMessage = nil
        isWorking = true
        defer { isWorking = false }
        do {
            try await client.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            return true
        } catch {
            errorMessage = "Sign in failed: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Account

    func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Permanently deletes the account and everything it owns, then signs out.
    func deleteAccount() async {
        isWorking = true
        defer { isWorking = false }
        do {
            try await client.rpc("delete_account").execute()
            try? await client.auth.signOut(scope: .local)
        } catch {
            errorMessage = "Couldn't delete your account: \(error.localizedDescription)"
        }
    }

    // MARK: - Helpers

    static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var generator = SystemRandomNumberGenerator()
        return String((0..<length).map { _ in charset.randomElement(using: &generator)! })
    }

    static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    /// `app_metadata.demo_location` is `{"latitude": …, "longitude": …}`, set by hand on demo accounts.
    static func demoCoordinate(from appMetadata: [String: AnyJSON]) -> CLLocationCoordinate2D? {
        guard case .object(let location)? = appMetadata["demo_location"],
              let latitude = location["latitude"]?.number,
              let longitude = location["longitude"]?.number,
              CLLocationCoordinate2DIsValid(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = PersonNameComponentsFormatter.localizedString(from: components, style: .default)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : String(name.prefix(50))
    }
}

private extension AnyJSON {
    /// A JSON number as a Double, whether it was written as an integer or a decimal.
    var number: Double? {
        switch self {
        case .double(let value): value
        case .integer(let value): Double(value)
        default: nil
        }
    }
}
