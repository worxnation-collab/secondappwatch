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

/// Orthodox stance: the lead side is the left.
public enum Hand: Sendable, Equatable {
    case lead, rear
    public var opposite: Hand { self == .lead ? .rear : .lead }
}

/// One entry in the moves library.
public enum Move: String, Codable, Sendable, CaseIterable {
    // Numbered punches, the boxing-gym standard.
    case jab, cross, leadHook, rearHook, leadUppercut, rearUppercut
    // Defense.
    case slip, roll
    // Muay Thai.
    case teep, leftKick, rightKick, knee, elbow

    public enum Kind: Sendable, Equatable { case punch, defense, kick, knee, elbow, teep }

    public var kind: Kind {
        switch self {
        case .jab, .cross, .leadHook, .rearHook, .leadUppercut, .rearUppercut: return .punch
        case .slip, .roll: return .defense
        case .leftKick, .rightKick: return .kick
        case .knee: return .knee
        case .elbow: return .elbow
        case .teep: return .teep
        }
    }

    /// 1–6 for punches, nil for everything else.
    public var number: Int? {
        switch self {
        case .jab: return 1
        case .cross: return 2
        case .leadHook: return 3
        case .rearHook: return 4
        case .leadUppercut: return 5
        case .rearUppercut: return 6
        default: return nil
        }
    }

    public static func punch(_ number: Int) -> Move {
        precondition((1...6).contains(number), "punches are numbered 1-6")
        return [.jab, .cross, .leadHook, .rearHook, .leadUppercut, .rearUppercut][number - 1]
    }

    /// Which hand throws it; nil for defense and the Muay Thai moves.
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
        case .slip: return "SLIP"
        case .roll: return "ROLL"
        case .teep: return "TEEP"
        case .leftKick: return "LEFT KICK"
        case .rightKick: return "RIGHT KICK"
        case .knee: return "KNEE"
        case .elbow: return "ELBOW"
        }
    }

    public var isStrike: Bool { kind != .defense }

    /// The library a discipline draws from.
    public static func library(for discipline: Discipline) -> [Move] {
        switch discipline {
        case .boxing: return allCases.filter { $0.kind == .punch || $0.kind == .defense }
        case .muayThai: return allCases.filter { $0.kind != .defense }
        }
    }
}

/// How a combo is written on the screen.
public enum CalloutStyle: String, Codable, Sendable, CaseIterable {
    /// "1-2-3". Moves without a number keep their name: "1-2-SLIP-2".
    case numbers
    /// "JAB-CROSS-HOOK".
    case names
}

public struct Combo: Sendable, Equatable {
    public let moves: [Move]
    public init(_ moves: [Move]) {
        precondition(!moves.isEmpty, "a combo has at least one move")
        self.moves = moves
    }

    public func callout(_ style: CalloutStyle) -> String {
        moves.map { move in
            if style == .numbers, let n = move.number { return String(n) }
            return move.name
        }.joined(separator: "-")
    }
}
