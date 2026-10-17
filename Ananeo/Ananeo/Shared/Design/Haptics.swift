import UIKit

/// Haptics for moments a view's state does not drive, like a message arriving over realtime.
/// Inside a view, prefer `.sensoryFeedback(_:trigger:)`, which `PillButtonStyle` already uses for presses.
@MainActor
enum Haptics {
    /// A pill press or a chip toggling.
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    /// A selection changing, like a segmented control.
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// A handoff confirmed, a listing posted.
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// A request that failed.
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
