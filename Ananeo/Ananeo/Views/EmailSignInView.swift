import SwiftUI

/// Password sign-in for accounts created by hand, such as the App Review demo account.
/// Reached from the small link under Sign in with Apple. There is no sign-up here on purpose.
struct EmailSignInView: View {
    @Environment(AuthService.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool {
        email.contains("@") && !password.isEmpty && !auth.isWorking
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xl) {
                    Text("Use the email and password you were given. Everyone else signs in with Apple.")
                        .font(.subheadline)
                        .foregroundStyle(AnaneoTheme.smoke)

                    VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm + 2) {
                        Text("Email").sectionLabel()
                        TextField("you@example.com", text: $email)
                            .textContentType(.username)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .focused($focus, equals: .email)
                            .onSubmit { focus = .password }
                            .field(isFocused: focus == .email)
                    }

                    VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.sm + 2) {
                        Text("Password").sectionLabel()
                        SecureField("Password", text: $password)
                            .textContentType(.password)
                            .submitLabel(.go)
                            .focused($focus, equals: .password)
                            .onSubmit { if canSubmit { Task { await signIn() } } }
                            .field(isFocused: focus == .password)
                    }

                    if let error = auth.errorMessage {
                        Text(error)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.red)
                    }

                    Button {
                        Task { await signIn() }
                    } label: {
                        if auth.isWorking {
                            LoopRing(progress: nil, lineWidth: 3, showsTrack: false).frame(width: 24)
                        } else {
                            Text("Sign In")
                        }
                    }
                    .buttonStyle(.pill)
                    .disabled(!canSubmit)
                }
                .padding(.horizontal, AnaneoTheme.Spacing.xl)
                .padding(.top, AnaneoTheme.Spacing.lg)
            }
            .background(AnaneoTheme.canvas)
            .navigationTitle("Sign in with email")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { focus = .email }
        }
        .preferredColorScheme(nil)
    }

    private func signIn() async {
        if await auth.signIn(email: email, password: password) {
            dismiss()
        }
    }
}

private extension View {
    /// The same bordered field as the Give form's title.
    func field(isFocused: Bool) -> some View {
        self
            .padding(.horizontal, AnaneoTheme.Spacing.lg)
            .frame(minHeight: AnaneoTheme.Size.pillButton)
            .background(AnaneoTheme.surface, in: RoundedRectangle(cornerRadius: AnaneoTheme.Radius.tile, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AnaneoTheme.Radius.tile, style: .continuous)
                    .strokeBorder(isFocused ? AnaneoTheme.leaf : AnaneoTheme.hairline, lineWidth: isFocused ? 2 : 1)
            }
    }
}

#Preview {
    EmailSignInView()
        .environment(AuthService())
}
