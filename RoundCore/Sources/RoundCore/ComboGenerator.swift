import Foundation

/// Builds combos from the moves library. Seeded, so a given seed always calls
/// the same workout, which is what lets the tests pin exact sequences.
///
/// The rules are the ones a coach would give, and each one is tested:
/// - Punches alternate hands. The one exception is the double jab (1-1).
/// - Defense (slip, roll) is never first, never last, never twice in a row.
/// - Muay Thai combos always land a kick, knee, elbow or teep, and a kick goes
///   off the OPPOSITE side to the last punch (1-2 → LEFT KICK, 1 → RIGHT
///   KICK), because that's the side your weight is already loaded on.
public struct ComboGenerator: Sendable {
    public let discipline: Discipline
    public let intensity: Intensity
    public let defense: Bool
    private var rng: SeededRandom

    public init(discipline: Discipline, intensity: Intensity, defense: Bool = false, seed: UInt64) {
        self.discipline = discipline
        self.intensity = intensity
        self.defense = defense
        rng = SeededRandom(seed: seed)
    }

    public init(workout: Workout, seed: UInt64) {
        self.init(discipline: workout.discipline, intensity: workout.intensity,
                  defense: workout.defense, seed: seed)
    }

    public mutating func next() -> Combo {
        let length = rng.int(in: intensity.comboLength)
        switch discipline {
        case .boxing: return boxing(length: length)
        case .muayThai: return muayThai(length: length)
        }
    }

    // MARK: Boxing

    private mutating func boxing(length: Int) -> Combo {
        var moves = punches(count: length)
        // Defense slots into the middle of a combo of three or more.
        if defense, length >= 3, rng.chance(40) {
            let slot = rng.int(in: 1...(length - 2))
            moves[slot] = rng.chance(50) ? .slip : .roll
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
