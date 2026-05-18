import Foundation

/// Lightweight semantic-version comparator. Handles the few patterns Notchy
/// actually publishes:
///   "0.5.0"  "0.5.1"  "1.0.0"  "v0.5.0"  "0.5.0-beta.2"
///
/// Pre-release identifiers (after `-`) compare lexically; the absence of one
/// means a higher precedence per SemVer 2.0.
struct SemVer: Comparable, Hashable, Sendable {
    let major: Int
    let minor: Int
    let patch: Int
    let preRelease: String?

    init(major: Int, minor: Int, patch: Int, preRelease: String? = nil) {
        self.major = major
        self.minor = minor
        self.patch = patch
        self.preRelease = preRelease
    }

    init?(_ raw: String) {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s = String(s.dropFirst()) }
        let preParts = s.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
        let core = preParts[0]
        let pre = preParts.count > 1 ? preParts[1] : nil
        let comps = core.split(separator: ".").map(String.init)
        guard comps.count >= 2,
              let mj = Int(comps[0]),
              let mn = Int(comps[1])
        else { return nil }
        let pt = comps.count > 2 ? (Int(comps[2]) ?? 0) : 0
        self.init(major: mj, minor: mn, patch: pt, preRelease: pre)
    }

    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        if lhs.major != rhs.major { return lhs.major < rhs.major }
        if lhs.minor != rhs.minor { return lhs.minor < rhs.minor }
        if lhs.patch != rhs.patch { return lhs.patch < rhs.patch }
        // SemVer 2.0: a pre-release version has lower precedence than the same
        // version without one.
        switch (lhs.preRelease, rhs.preRelease) {
        case (nil, nil): return false
        case (nil, _):   return false
        case (_, nil):   return true
        case let (a?, b?): return a < b
        }
    }

    var display: String {
        let base = "\(major).\(minor).\(patch)"
        if let pre = preRelease { return "\(base)-\(pre)" }
        return base
    }
}
