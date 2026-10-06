import Foundation
import SwiftUI
import UIKit

/// The puck's casing colour. It themes the whole app.
///
/// Every casing shares one lightness and chroma and only the hue changes, so any
/// hue stays calm (see design_handoff_reset_mobile/README.md, "Casing → accent").
struct Casing: Codable, Hashable, Identifiable {
    var name: String
    var hue: Double
    /// Graphite caps chroma at 0.012 for all three roles.
    var isNeutral: Bool = false

    var id: String { name }

    static let clay = Casing(name: "Clay", hue: 45)
    static let sage = Casing(name: "Sage", hue: 155)
    static let iris = Casing(name: "Iris", hue: 280)
    static let tide = Casing(name: "Tide", hue: 220)
    static let graphite = Casing(name: "Graphite", hue: 250, isNeutral: true)

    static let presets: [Casing] = [.clay, .sage, .iris, .tide, .graphite]
    static let `default` = Casing.clay

    static func custom(hue: Double) -> Casing {
        Casing(name: "Custom", hue: hue)
    }

    /// Finds the preset with this hue, or makes a custom casing for it.
    static func forHue(_ hue: Double) -> Casing {
        presets.first { $0.hue == hue } ?? .custom(hue: hue)
    }

    /// Puck, primary buttons, toggles on, chart fills.
    var accent: RGB { presetHex(\.accent) ?? RGB.oklch(l: 0.78, c: chroma(0.095), h: hue) }
    /// Locked and shield backgrounds, chips.
    var soft: RGB { presetHex(\.soft) ?? RGB.oklch(l: 0.95, c: chroma(0.035), h: hue) }
    /// Status lines and tinted text.
    var ink: RGB { presetHex(\.ink) ?? RGB.oklch(l: 0.42, c: chroma(0.12), h: hue) }

    private func chroma(_ c: Double) -> Double { isNeutral ? 0.012 : c }

    private struct Hexes { let accent: RGB; let soft: RGB; let ink: RGB }

    /// Presets use the exact hex values from tokens.json so they match the design pixel for pixel.
    private func presetHex(_ role: KeyPath<Hexes, RGB>) -> RGB? {
        let table: [String: Hexes] = [
            "Clay": Hexes(accent: RGB(hex: 0xEBA484), soft: RGB(hex: 0xFFE8DC), ink: RGB(hex: 0x803200)),
            "Sage": Hexes(accent: RGB(hex: 0x85CA9D), soft: RGB(hex: 0xDDF6E4), ink: RGB(hex: 0x005F2E)),
            "Iris": Hexes(accent: RGB(hex: 0xABB1F4), soft: RGB(hex: 0xE9EDFF), ink: RGB(hex: 0x42428C)),
            "Tide": Hexes(accent: RGB(hex: 0x6BC6E1), soft: RGB(hex: 0xD6F5FF), ink: RGB(hex: 0x005A7A)),
            "Graphite": Hexes(accent: RGB(hex: 0xB2B8BF), soft: RGB(hex: 0xE9EFF6), ink: RGB(hex: 0x484E54)),
        ]
        return table[name]?[keyPath: role]
    }
}

/// An sRGB colour with components in 0...1.
struct RGB: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    init(r: Double, g: Double, b: Double) {
        self.r = r; self.g = g; self.b = b
    }

    init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    /// OKLCH → sRGB (Björn Ottosson's OKLab matrices), clipped to gamut.
    static func oklch(l: Double, c: Double, h: Double) -> RGB {
        let rad = h * .pi / 180
        let a = c * cos(rad), b = c * sin(rad)

        let l_ = l + 0.3963377774 * a + 0.2158037573 * b
        let m_ = l - 0.1055613458 * a - 0.0638541728 * b
        let s_ = l - 0.0894841775 * a - 1.2914855480 * b
        let (lc, mc, sc) = (l_ * l_ * l_, m_ * m_ * m_, s_ * s_ * s_)

        let lr = 4.0767416621 * lc - 3.3077115913 * mc + 0.2309699292 * sc
        let lg = -1.2684380046 * lc + 2.6097574011 * mc - 0.3413193965 * sc
        let lb = -0.0041960863 * lc - 0.7034186147 * mc + 1.7076147010 * sc

        func encode(_ x: Double) -> Double {
            let v = x <= 0.0031308 ? 12.92 * x : 1.055 * pow(x, 1 / 2.4) - 0.055
            return min(max(v, 0), 1)
        }
        return RGB(r: encode(lr), g: encode(lg), b: encode(lb))
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b) }
    var uiColor: UIColor { UIColor(red: r, green: g, blue: b, alpha: 1) }
}
