import SwiftUI

/// One message. Yours fill with the gradient on the right; theirs sit on a card on the left with their initial.
struct ChatBubble: View {
    let message: Message
    let isMine: Bool
    /// The other person, for the badge beside their messages.
    let otherName: String
    /// Colors the other person's badge Sky when you are the one getting the item.
    var isGetting = false
    var showsTime = true

    var body: some View {
        HStack(alignment: .bottom, spacing: AnaneoTheme.Spacing.sm) {
            if isMine {
                Spacer(minLength: 48)
            } else {
                PersonBadge(name: otherName, isGetting: isGetting)
            }
            VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
                Text(message.body)
                    .foregroundStyle(isMine ? .white : AnaneoTheme.ink)
                    .padding(.horizontal, AnaneoTheme.Spacing.md + 2)
                    .padding(.vertical, AnaneoTheme.Spacing.sm + 2)
                    .background {
                        if isMine {
                            shape.fill(Self.mineGradient)
                                .shadow(color: AnaneoTheme.leaf.opacity(0.25), radius: 11, y: 8)
                        } else {
                            shape.fill(AnaneoTheme.surface)
                                .overlay { shape.strokeBorder(AnaneoTheme.hairline, lineWidth: 1) }
                        }
                    }
                if showsTime {
                    Text(message.createdAt, format: .dateTime.hour().minute())
                        .font(.caption2)
                        .foregroundStyle(AnaneoTheme.smoke)
                }
            }
            if !isMine {
                Spacer(minLength: 48)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// Round, except the corner nearest the sender, which is tucked in.
    private var shape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: AnaneoTheme.Radius.bubble,
            bottomLeadingRadius: isMine ? AnaneoTheme.Radius.bubble : 6,
            bottomTrailingRadius: isMine ? 6 : AnaneoTheme.Radius.bubble,
            topTrailingRadius: AnaneoTheme.Radius.bubble,
            style: .continuous
        )
    }

    private static let mineGradient = LinearGradient(
        colors: [Color(red: 15 / 255, green: 110 / 255, blue: 69 / 255), AnaneoTheme.leaf],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

#Preview("Chat bubbles") {
    let me = UUID()
    let them = UUID()
    VStack(spacing: AnaneoTheme.Spacing.sm + 2) {
        ChatBubble(message: .preview("Hi! Is the shelf still available? I could pick it up this weekend.", from: them, minutesAgo: 30), isMine: false, otherName: "Sam")
        ChatBubble(message: .preview("Yes! It's yours if Saturday works.", from: me, minutesAgo: 25), isMine: true, otherName: "Sam")
        ChatBubble(message: .preview("Perfect. Saturday around 10?", from: them, minutesAgo: 20), isMine: false, otherName: "Sam", isGetting: true)
    }
    .padding()
    .background(AnaneoTheme.canvas)
}
