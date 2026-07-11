import Foundation

@propertyWrapper
struct RobustDate: Codable, Hashable {
    var wrappedValue: Date
    
    init(wrappedValue: Date) {
        self.wrappedValue = wrappedValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        
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
