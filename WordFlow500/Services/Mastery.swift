import Foundation

enum Mastery {
    static func isMastered(level: Int) -> Bool {
        return level >= 10
    }

    static func bandFromLevel(_ level: Int) -> Double {
        let clamped = max(0, min(10, level))
        if clamped >= 10 { return 8.0 }
        if clamped >= 9 { return 7.5 }
        if clamped >= 7 { return 7.0 }
        if clamped >= 5 { return 6.5 }
        if clamped >= 3 { return 6.0 }
        if clamped >= 1 { return 5.5 }
        return 5.0
    }
}
