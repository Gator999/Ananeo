import AuthenticationServices
import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 72, weight: .semibold))
                .foregroundStyle(.tint)

            Text("Ananeo")
                .font(.largeTitle.bold())

            Text("Give More. Waste Less.\nKeep It Moving.")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Spacer()

            SignInWithAppleButton(.continue) { request in
                auth.prepare(request)
            } onCompletion: { result in
                Task { await auth.handle(result) }
            }
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 52)
            .disabled(auth.isWorking)
            .overlay {
                if auth.isWorking { ProgressView().tint(.secondary) }
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text("Your exact location is never shown to other people.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }
}

#Preview {
    SignInView()
        .environment(AuthService())
}
