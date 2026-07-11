import SwiftUI

/// The core color palette for Peak Messenger.
/// A strict monochrome (black & white) design system for a premium feel.
struct PeakColors {
    /// Pure black or white depending on color scheme (mostly we will force dark mode or use pure black as background in dark mode).
    static let background = Color("Background", bundle: nil) // We'll rely on system colors or custom
    
    // For a pure B&W app, we might just define them directly:
    
    /// Primary text and icons (White in dark mode, Black in light mode, but the app prefers dark mode)
    static let primary = Color.white
    
    /// True black background
    static let pureBlack = Color.black
    
    /// True white
    static let pureWhite = Color.white
    
    /// Secondary text and subtle borders
    static let secondary = Color(white: 0.6)
    
    /// Tertiary elements like placeholder text or faint dividers
    static let tertiary = Color(white: 0.3)
    
    /// A subtle gray for chat bubbles from others
    static let bubbleGray = Color(white: 0.15)
}

extension Color {
    // Convenience extensions if needed later
}
