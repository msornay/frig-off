/// ARCEP NPV (Numéros Polyvalents Virtuels) prefix ranges designated
/// for commercial prospecting calls ("démarchage téléphonique").
///
/// Each prefix maps to an E.164 range under +33 (France country code).
/// Metropolitan prefixes are 4-digit local prefixes (1M numbers each).
/// Overseas prefixes are 5-digit local prefixes (100K numbers each).

/// A French phone prefix range that should be blocked.
public struct BlockPrefix: Sendable, Equatable, Hashable {
    /// The local prefix digits (e.g., "0162" or "09475").
    public let localPrefix: String

    /// The E.164 prefix after +33 (e.g., "162" or "9475").
    /// Derived by stripping the leading "0" from `localPrefix`.
    public var e164Prefix: String {
        String(localPrefix.dropFirst())
    }

    /// The total number of digits in a complete E.164 number (after +33).
    /// French numbers are 9 digits after the country code.
    public static let e164DigitsAfterCountryCode = 9

    /// How many individual numbers this prefix expands to.
    public var numberCount: Int {
        var suffixLength = Self.e164DigitsAfterCountryCode - e164Prefix.count
        // Ensure non-negative
        if suffixLength < 0 { suffixLength = 0 }
        var result = 1
        for _ in 0..<suffixLength {
            result *= 10
        }
        return result
    }

    /// A human-readable description of the geographic zone.
    public let zone: String

    public init(localPrefix: String, zone: String) {
        self.localPrefix = localPrefix
        self.zone = zone
    }
}

/// All ARCEP-designated NPV prefixes for metropolitan France (12 prefixes, 4-digit).
public let metropolitanPrefixes: [BlockPrefix] = [
    BlockPrefix(localPrefix: "0162", zone: "Île-de-France"),
    BlockPrefix(localPrefix: "0163", zone: "Île-de-France"),
    BlockPrefix(localPrefix: "0270", zone: "Nord-Ouest"),
    BlockPrefix(localPrefix: "0271", zone: "Nord-Ouest"),
    BlockPrefix(localPrefix: "0377", zone: "Nord-Est"),
    BlockPrefix(localPrefix: "0378", zone: "Nord-Est"),
    BlockPrefix(localPrefix: "0424", zone: "Sud-Est"),
    BlockPrefix(localPrefix: "0425", zone: "Sud-Est"),
    BlockPrefix(localPrefix: "0568", zone: "Sud-Ouest"),
    BlockPrefix(localPrefix: "0569", zone: "Sud-Ouest"),
    BlockPrefix(localPrefix: "0948", zone: "France non-géographique"),
    BlockPrefix(localPrefix: "0949", zone: "France non-géographique"),
]

/// All ARCEP-designated NPV prefixes for overseas France (5 prefixes, 5-digit).
public let overseasPrefixes: [BlockPrefix] = [
    BlockPrefix(localPrefix: "09475", zone: "Outre-mer"),
    BlockPrefix(localPrefix: "09476", zone: "Outre-mer"),
    BlockPrefix(localPrefix: "09477", zone: "Outre-mer"),
    BlockPrefix(localPrefix: "09478", zone: "Outre-mer"),
    BlockPrefix(localPrefix: "09479", zone: "Outre-mer"),
]

/// All ARCEP NPV prefixes combined.
public let allPrefixes: [BlockPrefix] = metropolitanPrefixes + overseasPrefixes

/// Expand a single prefix into all individual E.164 phone numbers.
///
/// For example, prefix "0162" (e164Prefix "162") with 9 total digits
/// expands to "+33162000000" through "+33162999999" (1,000,000 numbers).
///
/// - Parameter prefix: The prefix to expand.
/// - Returns: An array of E.164 formatted phone numbers.
public func expandPrefix(_ prefix: BlockPrefix) -> [String] {
    let e164 = prefix.e164Prefix
    let suffixLength = BlockPrefix.e164DigitsAfterCountryCode - e164.count
    guard suffixLength >= 0 else { return [] }

    let count = prefix.numberCount
    var numbers: [String] = []
    numbers.reserveCapacity(count)

    for i in 0..<count {
        let suffix = String(format: "%0\(suffixLength)d", i)
        numbers.append("+33\(e164)\(suffix)")
    }
    return numbers
}

/// Lazily iterate over all E.164 numbers for a prefix without
/// materializing the full array in memory.
public struct PrefixIterator: Sequence, IteratorProtocol {
    let e164Prefix: String
    let suffixLength: Int
    let count: Int
    var current: Int = 0

    public init(prefix: BlockPrefix) {
        self.e164Prefix = prefix.e164Prefix
        self.suffixLength = BlockPrefix.e164DigitsAfterCountryCode - prefix.e164Prefix.count
        self.count = prefix.numberCount
    }

    public mutating func next() -> String? {
        guard current < count else { return nil }
        let suffix = String(format: "%0\(suffixLength)d", current)
        current += 1
        return "+33\(e164Prefix)\(suffix)"
    }
}
