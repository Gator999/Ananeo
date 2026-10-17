import SwiftUI

/// Four tabs on a glass bar, with the gradient Give button beside it. Content scrolls under a fade behind it.
struct FloatingTabBar: View {
    @Binding var selection: AppTab
    var pickupsBadge = 0
    var onGive: () -> Void

    var body: some View {
        HStack(spacing: AnaneoTheme.Spacing.xl) {
            GlassBar {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    tabButton(tab)
                }
            }
            giveButton
        }
        .padding(.horizontal, AnaneoTheme.Spacing.lg)
        .padding(.bottom, AnaneoTheme.Spacing.sm)
        .background(alignment: .bottom) { fade }
        .sensoryFeedback(.selection, trigger: selection)
        .accessibilityElement(children: .contain)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selection == tab
        return Button {
            selection = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.title3)
                    .symbolVariant(isSelected ? .fill : .none)
                Text(tab.title)
                    .font(.caption2.weight(isSelected ? .bold : .semibold))
            }
            .foregroundStyle(isSelected ? AnaneoTheme.progress : AnaneoTheme.smoke)
            .frame(maxWidth: .infinity)
            .frame(height: AnaneoTheme.Size.bar)
            .contentShape(Rectangle())
            .overlay(alignment: .topTrailing) {
                if tab == .pickups && pickupsBadge > 0 {
                    badge
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab == .pickups && pickupsBadge > 0 ? "\(tab.title), \(pickupsBadge) waiting on you" : tab.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var badge: some View {
        Text(pickupsBadge, format: .number)
            .numerals(.caption2)
            .foregroundStyle(.white)
            .padding(.horizontal, 5)
            .frame(minWidth: 18)
            .frame(height: 18)
            .background(AnaneoTheme.clay, in: Capsule())
            .padding(.top, AnaneoTheme.Spacing.sm)
            .padding(.trailing, AnaneoTheme.Spacing.sm + 2)
            .accessibilityHidden(true)
    }

    private var giveButton: some View {
        Button(action: onGive) {
            Image(systemName: "plus")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(AnaneoTheme.renewalButton, in: Circle())
                .overlay {
                    Circle()
                        .fill(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .center))
                        .allowsHitTesting(false)
                }
                .shadow(color: AnaneoTheme.leaf.opacity(0.38), radius: 14, y: 12)
        }
        .buttonStyle(PressScaleButtonStyle())
        .accessibilityLabel("Give something")
    }

    /// Lets feed content fade out under the bar instead of stopping dead above it.
    private var fade: some View {
        LinearGradient(
            colors: [AnaneoTheme.canvas.opacity(0), AnaneoTheme.canvas.opacity(0.92), AnaneoTheme.canvas],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 150)
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}

/// Scales the button down on press with a light haptic. For round and icon buttons that are not pills.
struct PressScaleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(AnaneoMotion.press(reduceMotion: reduceMotion), value: configuration.isPressed)
            .sensoryFeedback(trigger: configuration.isPressed) { _, isPressed in
                isPressed ? .impact(weight: .light) : nil
            }
    }
}

/// Set by screens that need the whole bottom edge, like a listing's action bar or a chat composer.
struct FloatingTabBarHiddenKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

extension View {
    /// Hides the floating tab bar while this screen is showing.
    func hidesFloatingTabBar(_ hidden: Bool = true) -> some View {
        preference(key: FloatingTabBarHiddenKey.self, value: hidden)
    }
}

#Preview("Floating tab bar") {
    struct Demo: View {
        @State private var selection: AppTab = .browse

        var body: some View {
            ZStack(alignment: .bottom) {
                AnaneoTheme.canvas.ignoresSafeArea()
                FloatingTabBar(selection: $selection, pickupsBadge: 2) {}
            }
        }
    }
    return Demo()
}
