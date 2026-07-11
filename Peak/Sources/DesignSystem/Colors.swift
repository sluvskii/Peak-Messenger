import SwiftUI

// MARK: — Peak Color System
// Strict B&W palette — monochrome, premium, timeless.

struct PeakColors {

    // MARK: Backgrounds
    /// True black — primary background
    static let black = Color.black
    /// Off-black — elevated surfaces (sheets, cards)
    static let surface = Color(white: 0.08)
    /// Subtle separator / divider
    static let divider = Color(white: 0.12)

    // MARK: Bubbles
    /// Incoming message bubble background
    static let bubbleIn  = Color(white: 0.13)
    /// Outgoing message bubble background
    static let bubbleOut = Color.white

    // MARK: Text
    /// Primary text — pure white
    static let textPrimary   = Color.white
    /// Secondary text — muted gray
    static let textSecondary = Color(white: 0.55)
    /// Tertiary text — very muted
    static let textTertiary  = Color(white: 0.35)

    // MARK: Interactive
    /// Accent — white (taps, selections)
    static let accent = Color.white
    /// Online indicator
    static let online = Color.white
    /// Destructive action
    static let destructive = Color(white: 0.8)

    // MARK: Avatar tints (for initials avatars)
    static let avatarTints: [Color] = [
        Color(white: 0.18),
        Color(white: 0.14),
        Color(white: 0.20),
        Color(white: 0.16),
    ]

    static func avatarTint(for id: String) -> Color {
        let idx = abs(id.hashValue) % avatarTints.count
        return avatarTints[idx]
    }
}
