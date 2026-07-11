import SwiftUI

// MARK: — Reusable Avatar View

struct AvatarView: View {
    let user: User
    let size: CGFloat
    var showOnline: Bool = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let urlString = user.avatarUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: size, height: size)
                            .background(PeakColors.avatarTint(for: user.id.uuidString))
                            .clipShape(Circle())
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: size, height: size)
                            .clipShape(Circle())
                    case .failure:
                        fallbackAvatar
                    @unknown default:
                        fallbackAvatar
                    }
                }
            } else {
                fallbackAvatar
            }

            if showOnline && user.isOnline {
                Circle()
                    .fill(PeakColors.black)
                    .frame(width: size * 0.28 + 2, height: size * 0.28 + 2)
                    .overlay(
                        Circle()
                            .fill(PeakColors.online)
                            .frame(width: size * 0.28, height: size * 0.28)
                    )
                    .offset(x: 1, y: 1)
            }
        }
    }
    
    private var fallbackAvatar: some View {
        Circle()
            .fill(PeakColors.avatarTint(for: user.id.uuidString))
            .shadow(color: PeakColors.avatarTint(for: user.id.uuidString).opacity(0.15), radius: size * 0.15, y: size * 0.05)
            .frame(width: size, height: size)
            .overlay(
                Text(user.initials)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(PeakColors.textPrimary)
            )
    }
}

// MARK: — Unread Badge

struct UnreadBadge: View {
    let count: Int

    var body: some View {
        if count > 0 {
            Text(count > 99 ? "99+" : "\(count)")
                .font(PeakTypography.tiny)
                .foregroundStyle(PeakColors.black)
                .padding(.horizontal, count > 9 ? 6 : 5)
                .padding(.vertical, 3)
                .background(PeakColors.textPrimary)
                .clipShape(Capsule())
        }
    }
}

// MARK: — Press Effect Button Style

struct PressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.75 : 1.0)
            .animation(.spring(duration: 0.2, bounce: 0.3), value: configuration.isPressed)
    }
}

// MARK: — Hairline divider

struct PeakDivider: View {
    var body: some View {
        Rectangle()
            .fill(PeakColors.divider)
            .frame(height: 0.5)
    }
}
