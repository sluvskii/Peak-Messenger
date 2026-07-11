import Foundation

@propertyWrapper
struct RobustDate: Codable, Hashable {
    var wrappedValue: Date
    
    init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        var string = try container.decode(String.self)
        
        // Fix for Supabase 6-digit microseconds: ISO8601DateFormatter expects 3 digits.
        // E.g. "2026-07-11T17:42:38.123456+00:00" -> truncate to 3 digits before timezone
        if let dotIndex = string.lastIndex(of: ".") {
            let timezoneIndex = string.firstIndex(of: "+") ?? string.firstIndex(of: "Z") ?? string.endIndex
            let fractionLength = string.distance(from: string.index(after: dotIndex), to: timezoneIndex)
            
            if fractionLength > 3 {
                let endOfFraction = string.index(string.index(after: dotIndex), offsetBy: 3)
                string.replaceSubrange(endOfFraction..<timezoneIndex, with: "")
            }
        }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            self.wrappedValue = date
            return
        }
        
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: string) {
            self.wrappedValue = date
            return
        }
        
        throw DecodingError.dataCorruptedError(
            in: container,
            debugDescription: "Invalid date format: \(string)"
        )
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let string = formatter.string(from: wrappedValue)
        try container.encode(string)
    }
}
