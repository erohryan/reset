import SwiftUI

/// Lab Notebook tokens. Source of truth: design_handoff_reset_mobile/tokens.json.
enum Theme {
    // Neutrals
    static let paper = Color(hex: 0xFFFDF7)
    static let canvas = Color(hex: 0xF7F4EC)
    static let gridLine = Color(hex: 0xF3EEE2)
    static let divider = Color(hex: 0xE0D9C8)
    static let muted = Color(hex: 0x9B9484)
    static let subtle = Color(hex: 0x7A7468)
    static let body = Color(hex: 0x4D483F)
    static let ink = Color(hex: 0x2A2722)
    /// Glyph colour on napping tiles.
    static let nappingGlyph = Color(hex: 0xB3AB98)

    static let border: CGFloat = 1.5

    enum Shadow {
        static let s: CGFloat = 3
        static let m: CGFloat = 4
        static let l: CGFloat = 5
        static let puck: CGFloat = 7
    }

    enum Radius {
        static let tileS: CGFloat = 11
        static let tile: CGFloat = 16
        static let shieldTile: CGFloat = 22
        static let card: CGFloat = 18
        static let cardL: CGFloat = 20
    }

    /// Screen padding: 64px top in the 760px frame includes the status bar, so the
    /// safe-area-relative top is smaller.
    enum Screen {
        static let top: CGFloat = 16
        static let sides: CGFloat = 24
        static let bottom: CGFloat = 28
        static let gap: CGFloat = 14
    }

    static let screenIn = Animation.easeOut(duration: 0.35)
}

/// Type roles from the design README.
enum RFont {
    static func display(_ size: CGFloat) -> Font {
        .custom("InstrumentSerif-Italic", size: size)
    }

    static func body(_ size: CGFloat = 15, _ weight: Font.Weight = .regular) -> Font {
        .custom("Figtree", size: size).weight(weight)
    }

    static func mono(_ size: CGFloat = 12, _ weight: Font.Weight = .regular) -> Font {
        .custom("JetBrains Mono", size: size).weight(weight)
    }

    static let button = body(16, .semibold)
    static let label = mono(12)
    static let caption = mono(11)
    static let timerL = mono(36, .medium)
    static let timerM = mono(26, .medium)
}

extension Color {
    init(hex: UInt32) {
        self = RGB(hex: hex).color
    }
}

// MARK: Casing in the environment

private struct CasingKey: EnvironmentKey {
    static let defaultValue = Casing.default
}

extension EnvironmentValues {
    /// The puck's casing. Every component reads its accent, soft and ink from here.
    var casing: Casing {
        get { self[CasingKey.self] }
        set { self[CasingKey.self] = newValue }
    }
}
