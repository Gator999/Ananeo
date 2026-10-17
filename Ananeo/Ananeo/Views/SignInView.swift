import AuthenticationServices
import SwiftUI

/// Welcome: the loop draws itself on the drifting Renewal mesh, the tagline fades in word by word,
/// and everyone's running total sits in a glass pill above Sign in with Apple.
struct SignInView: View {
    @Environment(AuthService.self) private var auth
    @Environment(ListingService.self) private var listings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var drawn = 0.0
    @State private var revealedWords = 0
    @State private var community: CommunityImpact?
    @ScaledMetric private var wordmarkSize: CGFloat = 56

    private static let lines = [["Give", "More."], ["Waste", "Less."], ["Keep", "It", "Moving."]]
    private static let wordCount = lines.reduce(0) { $0 + $1.count }

    var body: some View {
        ZStack {
            MeshBackdrop()
            VStack(spacing: AnaneoTheme.Spacing.xxl + 10) {
                Spacer(minLength: AnaneoTheme.Spacing.xxl)
                LoopMark(primary: .white, secondary: AnaneoTheme.spark, drawn: drawn)
                    .frame(width: 172, height: 172)
                    .shadow(color: .black.opacity(0.35), radius: 24, y: 18)
                    .accessibilityHidden(true)
                VStack(spacing: AnaneoTheme.Spacing.md + 2) {
                    Text("Ananeo")
                        .font(.system(size: wordmarkSize, weight: .heavy))
                        .tracking(-1.5)
                        .foregroundStyle(.white)
                    tagline
                }
                communityPill
                Spacer()
                Spacer()
            }
            .padding(.horizontal, AnaneoTheme.Spacing.xxl)
        }
        .safeAreaInset(edge: .bottom) { signIn }
        .preferredColorScheme(.dark)
        .task { await reveal() }
        .task { community = try? await listings.communityImpact() }
        .animation(AnaneoMotion.settle(reduceMotion: reduceMotion), value: community)
    }

    private var tagline: some View {
        VStack(spacing: 2) {
            ForEach(Array(Self.lines.enumerated()), id: \.offset) { lineIndex, words in
                HStack(spacing: 5) {
                    ForEach(Array(words.enumerated()), id: \.offset) { wordIndex, word in
                        Text(word)
                            .opacity(wordNumber(lineIndex, wordIndex) < revealedWords ? 1 : 0)
                    }
                }
            }
        }
        .font(.title3.weight(.semibold))
        .foregroundStyle(AnaneoTheme.mint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Give More. Waste Less. Keep It Moving.")
    }

    private func wordNumber(_ line: Int, _ word: Int) -> Int {
        Self.lines.prefix(line).reduce(0) { $0 + $1.count } + word
    }

    @ViewBuilder
    private var communityPill: some View {
        if let community, community.itemsKeptMoving > 0 {
            HStack(spacing: AnaneoTheme.Spacing.sm + 2) {
                LoopMark.onGradient.frame(width: 20, height: 20)
                (Text(community.itemsKeptMoving, format: .number).font(AnaneoTheme.Typography.numerals(.subheadline))
                    + Text(" items kept moving so far"))
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, AnaneoTheme.Spacing.lg)
            .frame(minHeight: 40)
            .background(.white.opacity(0.12), in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1) }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .accessibilityElement(children: .combine)
        }
    }

    private var signIn: some View {
        VStack(spacing: AnaneoTheme.Spacing.lg) {
            SignInWithAppleButton(.continue) { request in
                auth.prepare(request)
            } onCompletion: { result in
                Task { await auth.handle(result) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(minHeight: AnaneoTheme.Size.pillButton)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.35), radius: 17, y: 14)
            .disabled(auth.isWorking)
            .overlay {
                if auth.isWorking {
                    LoopRing(progress: nil, lineWidth: 3, showsTrack: false)
                        .frame(width: 24)
                        .environment(\.colorScheme, .light)
                }
            }

            if let error = auth.errorMessage {
                Text(error)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AnaneoTheme.sun)
                    .multilineTextAlignment(.center)
            }

            Text("Your exact location is never shown to other people.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.78))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, AnaneoTheme.Spacing.xxl)
        .padding(.bottom, AnaneoTheme.Spacing.lg)
    }

    /// Draws the loop, then reveals the tagline a word at a time. All at once under Reduce Motion.
    private func reveal() async {
        if reduceMotion {
            drawn = 1
            revealedWords = Self.wordCount
            return
        }
        withAnimation(.spring(duration: 1.2, bounce: 0.15)) { drawn = 1 }
        try? await Task.sleep(for: .seconds(0.9))
        for _ in 0..<Self.wordCount {
            if Task.isCancelled { return }
            withAnimation(.easeOut(duration: 0.35)) { revealedWords += 1 }
            try? await Task.sleep(for: .milliseconds(140))
        }
    }
}

#Preview {
    SignInView()
        .environment(AuthService())
        .environment(ListingService())
}
