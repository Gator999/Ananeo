import SwiftUI

/// The message field on glass, with a gradient send button. Grows to five lines.
struct Composer: View {
    @Binding var text: String
    var placeholder = "Message"
    var isSending = false
    var errorMessage: String?
    var onSend: () -> Void

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var canSend: Bool { !trimmed.isEmpty && trimmed.count <= 2000 && !isSending }

    var body: some View {
        VStack(alignment: .leading, spacing: AnaneoTheme.Spacing.xs + 2) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, AnaneoTheme.Spacing.sm)
            }
            HStack(alignment: .bottom, spacing: AnaneoTheme.Spacing.sm + 2) {
                TextField(placeholder, text: $text, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(.horizontal, AnaneoTheme.Spacing.lg)
                    .padding(.vertical, AnaneoTheme.Spacing.md)
                    .background { GlassBackground(shape: RoundedRectangle(cornerRadius: 22, style: .continuous)) }
                Button(action: onSend) {
                    Group {
                        if isSending {
                            LoopRing(progress: nil, lineWidth: 3, style: .white, showsTrack: false)
                                .frame(width: 20)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.title3.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(canSend ? AnyShapeStyle(AnaneoTheme.renewalButton) : AnyShapeStyle(AnaneoTheme.track), in: Circle())
                    .shadow(color: canSend ? AnaneoTheme.leaf.opacity(0.3) : .clear, radius: 10, y: 8)
                }
                .buttonStyle(PressScaleButtonStyle())
                .disabled(!canSend)
                .accessibilityLabel("Send")
            }
        }
        .padding(.horizontal, AnaneoTheme.Spacing.lg)
        .padding(.vertical, AnaneoTheme.Spacing.sm + 2)
    }
}

#Preview("Composer") {
    struct Demo: View {
        @State private var text = ""

        var body: some View {
            VStack {
                Spacer()
                Composer(text: $text, placeholder: "Message Sam…") { text = "" }
                    .background(.bar)
            }
            .background(AnaneoTheme.canvas)
        }
    }
    return Demo()
}
