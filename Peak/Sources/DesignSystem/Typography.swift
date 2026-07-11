import SwiftUI

/// Typography definitions for Peak Messenger.
struct PeakTypography {
    
    /// Main logo font, large and bold
    static let logoFont = Font.system(size: 40, weight: .black, design: .default)
    
    /// Large titles for headers (e.g. Chat list header)
    static let title = Font.system(size: 32, weight: .bold, design: .default)
    
    /// Standard body text for messages
    static let body = Font.system(size: 17, weight: .regular, design: .default)
    
    /// Buttons
    static let button = Font.system(size: 17, weight: .semibold, design: .default)
    
    /// Small captions (timestamps, read receipts)
    static let caption = Font.system(size: 12, weight: .medium, design: .default)
}
