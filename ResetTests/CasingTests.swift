import XCTest
@testable import ResetDemo

final class CasingTests: XCTestCase {
    /// The OKLCH formula should land on the design's hex values for in-gamut colours,
    /// so custom hues look like they belong with the presets.
    func testOKLCHMatchesDesignAccents() {
        let cases: [(Double, UInt32)] = [(45, 0xEBA484), (155, 0x85CA9D), (280, 0xABB1F4), (220, 0x6BC6E1)]
        for (hue, hex) in cases {
            let computed = RGB.oklch(l: 0.78, c: 0.095, h: hue)
            let expected = RGB(hex: hex)
            XCTAssertEqual(computed.r, expected.r, accuracy: 4 / 255, "hue \(hue) red")
            XCTAssertEqual(computed.g, expected.g, accuracy: 4 / 255, "hue \(hue) green")
            XCTAssertEqual(computed.b, expected.b, accuracy: 4 / 255, "hue \(hue) blue")
        }
    }

    func testPresetsUseExactTokens() {
        XCTAssertEqual(Casing.clay.accent, RGB(hex: 0xEBA484))
        XCTAssertEqual(Casing.sage.ink, RGB(hex: 0x005F2E))
        XCTAssertEqual(Casing.graphite.soft, RGB(hex: 0xE9EFF6))
    }

    func testForHueFindsPresetOrMakesCustom() {
        XCTAssertEqual(Casing.forHue(220), .tide)
        XCTAssertEqual(Casing.forHue(10).name, "Custom")
    }

    func testPuckPayloadFitsOnNTAG213() throws {
        // NTAG213 has 144 bytes of user memory; leave room for NDEF headers and the MIME type.
        let json = try JSONEncoder().encode(PuckPayload(secret: PuckPayload.makeSecret(), hue: 280))
        XCTAssertLessThan(json.count + PuckPayload.mimeType.utf8.count + 8, 137)
    }

    func testDurationFormats() {
        XCTAssertEqual(DurationFormat.clock(5049), "01:24:09")
        XCTAssertEqual(DurationFormat.short(11_520), "3h 12m")
        XCTAssertEqual(DurationFormat.short(720), "12m")
    }
}
