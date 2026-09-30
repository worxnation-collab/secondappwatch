import Foundation

/// SplitMix64. The standard library's generators are unseedable, and relying
/// on `Int.random(in:using:)` would tie the tests to how the stdlib happens to
/// consume bits — so every draw here goes through `int(below:)`, which is ours.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Uniform in 0..<n, without modulo bias.
    public mutating func int(below n: Int) -> Int {
        precondition(n > 0)
        let bound = UInt64(n)
        let limit = UInt64.max - UInt64.max % bound
        while true {
            let v = next()
            if v < limit { return Int(v % bound) }
        }
    }

    public mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + int(below: range.count)
    }

    /// True with probability `percent`/100.
    public mutating func chance(_ percent: Int) -> Bool { int(below: 100) < percent }

    /// Picks from (value, weight) pairs.
    public mutating func weighted<T>(_ options: [(T, Int)]) -> T {
        let total = options.reduce(0) { $0 + $1.1 }
        precondition(total > 0)
        var roll = int(below: total)
        for (value, weight) in options {
            if roll < weight { return value }
            roll -= weight
        }
        return options[options.count - 1].0
    }
}
