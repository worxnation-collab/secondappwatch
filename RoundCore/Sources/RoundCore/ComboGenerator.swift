import Foundation

/// Builds combos from the moves library. Seeded, so a given seed always calls
/// the same workout, which is what lets the tests pin exact sequences.
///
/// The rules are the ones a coach would give, and each one is tested:
/// - Punches alternate hands. The one exception is the double jab (1-1).
/// - Body shots are only ever 1B–4B, and only in boxing.
/// - Evasions (slip, roll, duck, pull, parry) are never first, never last,
///   never twice in a row. A pivot only ever ENDS a combo: it's how you leave.
/// - Muay Thai combos always land a kick, knee, elbow or teep, and a kick goes
///   off the OPPOSITE side to the last punch (1-2 → LEFT KICK, 1 → RIGHT
///   KICK), because that's the side your weight is already loaded on.
public struct ComboGenerator: Sendable {
    public let discipline: Discipline
    public let intensity: Intensity
    public let defense: Bool
    public let bodyShots: Bool
    /// When non-empty, combos are drawn from here instead of generated.
    public let mine: [Combo]
    private var rng: SeededRandom
    private var lastMine: Int?

    public init(discipline: Discipline, intensity: Intensity, defense: Bool = false,
                bodyShots: Bool = false, mine: [Combo] = [], seed: UInt64) {
        self.discipline = discipline
        self.intensity = intensity
        self.defense = defense
        self.bodyShots = bodyShots
        self.mine = mine
        rng = SeededRandom(seed: seed)
    }

    /// `mine` is only used when the workout asks for it; an empty list falls
    /// back to generating, so a workout set to "My combos" still calls combos
    /// before you've built any.
    public init(workout: Workout, mine: [Combo] = [], seed: UInt64) {
        self.init(discipline: workout.discipline, intensity: workout.intensity,
                  defense: workout.defense, bodyShots: workout.bodyShots,
                  mine: workout.comboSource == .mine ? mine : [], seed: seed)
    }

    public mutating func next() -> Combo {
        if !mine.isEmpty { return nextOfMine() }
        let length = rng.int(in: intensity.comboLength)
        switch discipline {
        case .boxing: return boxing(length: length)
        case .muayThai: return muayThai(length: length)
        }
    }

    /// A random one of your combos, never the same one twice in a row.
    private mutating func nextOfMine() -> Combo {
        var i = rng.int(below: mine.count)
        if mine.count > 1, i == lastMine { i = (i + 1 + rng.int(below: mine.count - 1)) % mine.count }
        lastMine = i
        return mine[i]
    }

    // MARK: Boxing

    private mutating func boxing(length: Int) -> Combo {
        var moves = punches(count: length)
        if bodyShots {
            for i in moves.indices {
                if let body = moves[i].bodyVersion, rng.chance(20) { moves[i] = body }
            }
        }
        // Defense slots into the middle of a combo of three or more…
        if defense, length >= 3, rng.chance(40) {
            let slot = rng.int(in: 1...(length - 2))
            moves[slot] = rng.weighted([(.slip, 30), (.roll, 25), (.duck, 15), (.pull, 15), (.parry, 15)])
        }
        // …and a pivot can take the last beat, unless it would follow an
        // evasion (dodging straight into walking away isn't a combo).
        if defense, length >= 3, moves[length - 2].kind != .defense, rng.chance(20) {
            moves[length - 1] = .pivot
        }
        return Combo(moves)
    }

    /// `count` punches that alternate hands (a double jab allowed as 1-1).
    private mutating func punches(count: Int) -> [Move] {
        guard count > 0 else { return [] }
        var moves: [Move] = [rng.weighted([(.jab, 55), (.cross, 20), (.leadHook, 15), (.leadUppercut, 10)])]
        while moves.count < count {
            let last = moves[moves.count - 1]
            if last == .jab, moves.count == 1, rng.chance(15) {
                moves.append(.jab)
                continue
            }
            moves.append(nextPunch(after: last.hand ?? .lead))
        }
        return moves
    }

    private mutating func nextPunch(after hand: Hand) -> Move {
        switch hand.opposite {
        case .rear: return rng.weighted([(.cross, 50), (.rearHook, 30), (.rearUppercut, 20)])
        case .lead: return rng.weighted([(.jab, 35), (.leadHook, 45), (.leadUppercut, 20)])
        }
    }

    // MARK: Muay Thai

    private mutating func muayThai(length: Int) -> Combo {
        if length == 1 {
            return Combo([rng.weighted([(.teep, 25), (.rightKick, 30), (.leftKick, 20), (.knee, 25)])])
        }
        let lead = punches(count: length - 1)
        let lastHand = lead.last?.hand ?? .lead
        let kickOffOpposite: Move = lastHand == .rear ? .leftKick : .rightKick
        let finisher: Move = rng.weighted([(kickOffOpposite, 55), (.knee, 30), (.elbow, 15)])
        return Combo(lead + [finisher])
    }
}
