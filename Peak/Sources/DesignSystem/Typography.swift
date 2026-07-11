import SwiftUI

// MARK: — Peak Typography

struct PeakTypography {

    // Display
    static let logo     = Font.system(size: 28, weight: .black,    design: .default)
    static let display  = Font.system(size: 34, weight: .bold,     design: .default)

    // Navigation
    static let navTitle = Font.system(size: 17, weight: .semibold, design: .default)

    // Body
    static let headline = Font.system(size: 17, weight: .semibold, design: .default)
    static let body     = Font.system(size: 16, weight: .regular,  design: .default)
    static let bodyMedium = Font.system(size: 16, weight: .medium, design: .default)
    static let callout  = Font.system(size: 15, weight: .regular,  design: .default)

    // Small
    static let caption  = Font.system(size: 12, weight: .medium,   design: .default)
    static let tiny     = Font.system(size: 11, weight: .regular,  design: .default)

    // Button
    static let button   = Font.system(size: 16, weight: .semibold, design: .default)
}
