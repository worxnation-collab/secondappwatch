import Foundation

public enum Discipline: String, Codable, Sendable, CaseIterable {
    case boxing
    case muayThai

    public var title: String {
        switch self {
        case .boxing: return "Boxing"
        case .muayThai: return "Muay Thai"
        }
    }
}

/// Lead or rear. Boxing's numbers are stance-relative (1 is always the jab,
/// whichever hand leads), so nothing here needs to know about southpaw.
public enum Hand: Sendable, Equatable {
    case lead, rear
    public var opposite: Hand { self == .lead ? .rear : .lead }
}

/// One entry in the moves library.
public enum Move: String, Codable, Sendable, CaseIterable {
    // Numbered punches to the head, the boxing-gym standard.
    case jab, cross, leadHook, rearHook, leadUppercut, rearUppercut
    // The same punches to the body: 1B–4B. Uppercuts stay to the head.
    case bodyJab, bodyCross, bodyHook, bodyRearHook
    // Defense: evasions that live INSIDE a combo…
    case slip, roll, duck, pull, parry
    // …and footwork that ends one.
    case pivot
    // Muay Thai.
    case teep, leftKick, rightKick, knee, elbow

    public enum Kind: Sendable, Equatable { case punch, defense, footwork, kick, knee, elbow, teep }

    public var kind: Kind {
        switch self {
        case .jab, .cross, .leadHook, .rearHook, .leadUppercut, .rearUppercut,
             .bodyJab, .bodyCross, .bodyHook, .bodyRearHook: return .punch
        case .slip, .roll, .duck, .pull, .parry: return .defense
        case .pivot: return .footwork
        case .leftKick, .rightKick: return .kick
        case .knee: return .knee
        case .elbow: return .elbow
        case .teep: return .teep
        }
    }

    /// 1–6 for punches (body shots share their head punch's number), nil for
    /// everything else.
    public var number: Int? {
        switch self {
        case .jab, .bodyJab: return 1
        case .cross, .bodyCross: return 2
        case .leadHook, .bodyHook: return 3
        case .rearHook, .bodyRearHook: return 4
        case .leadUppercut: return 5
        case .rearUppercut: return 6
        default: return nil
        }
    }

    public var isBody: Bool { self == .bodyJab || self == .bodyCross || self == .bodyHook || self == .bodyRearHook }

    /// "1", "3B"; nil for anything without a number.
    public var code: String? {
        guard let n = number else { return nil }
        return isBody ? "\(n)B" : "\(n)"
    }

    public static func punch(_ number: Int) -> Move {
        precondition((1...6).contains(number), "punches are numbered 1-6")
        return [.jab, .cross, .leadHook, .rearHook, .leadUppercut, .rearUppercut][number - 1]
    }

    /// The same punch to the body, where there is one.
    public var bodyVersion: Move? {
        switch self {
        case .jab: return .bodyJab
        case .cross: return .bodyCross
        case .leadHook: return .bodyHook
        case .rearHook: return .bodyRearHook
        default: return nil
        }
    }

    /// The head punch a body shot is a version of (itself for everything else).
    public var headVersion: Move {
        switch self {
        case .bodyJab: return .jab
        case .bodyCross: return .cross
        case .bodyHook: return .leadHook
        case .bodyRearHook: return .rearHook
        default: return self
        }
    }

    /// Which hand throws it; nil for defense, footwork and the Muay Thai moves.
    public var hand: Hand? {
        guard let n = number else { return nil }
        return n % 2 == 1 ? .lead : .rear
    }

    public var name: String {
        switch self {
        case .jab: return "JAB"
        case .cross: return "CROSS"
        case .leadHook: return "HOOK"
        case .rearHook: return "REAR HOOK"
        case .leadUppercut: return "UPPERCUT"
        case .rearUppercut: return "REAR UPPER"
        case .bodyJab: return "BODY JAB"
        case .bodyCross: return "BODY CROSS"
        case .bodyHook: return "BODY HOOK"
        case .bodyRearHook: return "BODY REAR HOOK"
        case .slip: return "SLIP"
        case .roll: return "ROLL"
        case .duck: return "DUCK"
        case .pull: return "PULL"
        case .parry: return "PARRY"
        case .pivot: return "PIVOT"
        case .teep: return "TEEP"
        case .leftKick: return "LEFT KICK"
        case .rightKick: return "RIGHT KICK"
        case .knee: return "KNEE"
        case .elbow: return "ELBOW"
        }
    }

    public var isStrike: Bool { kind != .defense && kind != .footwork }

    /// The library a discipline draws from.
    public static func library(for discipline: Discipline) -> [Move] {
        switch discipline {
        case .boxing: return allCases.filter { [.punch, .defense, .footwork].contains($0.kind) }
        case .muayThai: return allCases.filter { !$0.isBody && $0.kind != .defense && $0.kind != .footwork }
        }
    }
}

/// How a combo is written on the screen.
public enum CalloutStyle: String, Codable, Sendable, CaseIterable {
    /// "1-2-3B". Moves without a number keep their name: "1-2-SLIP-2".
    case numbers
    /// "JAB-CROSS-HOOK".
    case names

    public var title: String { self == .numbers ? "Numbers" : "Names" }
}

public struct Combo: Codable, Sendable, Equatable, Hashable {
    public let moves: [Move]

    public init(_ moves: [Move]) {
        precondition(!moves.isEmpty, "a combo has at least one move")
        self.moves = moves
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let moves = try c.decode([Move].self, forKey: .moves)
        guard !moves.isEmpty else {
            throw DecodingError.dataCorruptedError(forKey: .moves, in: c, debugDescription: "empty combo")
        }
        self.moves = moves
    }

    public func callout(_ style: CalloutStyle) -> String {
        moves.map { move in
            if style == .numbers, let code = move.code { return code }
            return move.name
        }.joined(separator: "-")
    }

    /// The longest combo you can build by hand. Six taps at 0.14s is under a
    /// second of haptics, and past six nobody is counting.
    public static let maxBuiltLength = 6
}
