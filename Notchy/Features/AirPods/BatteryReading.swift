import Foundation

struct BatteryReading: Equatable, Sendable {
    var left: Int?
    var right: Int?
    var caseLevel: Int?

    /// Parses IORegistry/IOBluetooth values that can be Int (already %), String ("82%"), or Double (0.82).
    static func parse(left: Any?, right: Any?, caseValue: Any?) -> BatteryReading {
        BatteryReading(left: normalize(left), right: normalize(right), caseLevel: normalize(caseValue))
    }

    private static func normalize(_ any: Any?) -> Int? {
        switch any {
        case let i as Int where (0...100).contains(i): return i
        case let s as String:
            let stripped = s.replacingOccurrences(of: "%", with: "")
            return Int(stripped).flatMap { (0...100).contains($0) ? $0 : nil }
        case let d as Double where (0...1).contains(d): return Int(d * 100)
        case let d as Double where (0...100).contains(d): return Int(d)
        default: return nil
        }
    }
}
