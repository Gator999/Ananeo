import SwiftUI

/// A centered chip for something that happened on the pickup, like a reservation or a confirmation.
struct SystemEventChip: View {
    let text: String
    var systemImage = "arrow.left.arrow.right"

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.bold))
            .foregroundStyle(AnaneoTheme.progress)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AnaneoTheme.Spacing.md)
            .padding(.vertical, AnaneoTheme.Spacing.xs + 2)
            .background(AnaneoTheme.progress.opacity(0.12), in: Capsule())
            .frame(maxWidth: .infinity)
    }
}

/// The day a run of messages was sent, between runs.
struct ChatDayLabel: View {
    let date: Date

    var body: some View {
        Text(date, format: Calendar.current.isDateInToday(date) ? .dateTime.hour().minute() : .dateTime.weekday(.wide).month().day())
            .sectionLabel()
            .frame(maxWidth: .infinity)
            .padding(.vertical, AnaneoTheme.Spacing.xs)
    }
}

#Preview("System events") {
    VStack(spacing: AnaneoTheme.Spacing.md) {
        ChatDayLabel(date: .now.addingTimeInterval(-86400 * 2))
        SystemEventChip(text: "You reserved it for Sam")
        SystemEventChip(text: "Sam confirmed the handoff", systemImage: "checkmark")
        SystemEventChip(text: "Handed off Oct 14", systemImage: "checkmark.circle.fill")
    }
    .padding()
    .background(AnaneoTheme.canvas)
}
