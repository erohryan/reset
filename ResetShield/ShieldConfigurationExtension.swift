import ManagedSettings
import ManagedSettingsUI
import UIKit

/// The screen iOS shows when a napping app is opened. iOS only allows a background
/// colour, an icon, text and buttons here, so this is the Lab Notebook shield within those limits.
final class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: application.localizedDisplayName)
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make(name: webDomain.domain)
    }

    private func make(name: String?) -> ShieldConfiguration {
        let shared = SharedState()
        let casing = shared.casing
        let ink = RGB(hex: 0x2A2722).uiColor
        let elapsed = shared.restingSince.map { DurationFormat.short(Date().timeIntervalSince($0)) } ?? "a while"

        return ShieldConfiguration(
            backgroundBlurStyle: nil,
            backgroundColor: casing.soft.uiColor,
            icon: PuckIcon.image(casing: casing),
            title: .init(text: "Shh. \(name ?? "This app") is napping.", color: ink),
            subtitle: .init(text: "Reset for \(elapsed). Tap your phone on the puck to wake it.", color: RGB(hex: 0x4D483F).uiColor),
            primaryButtonLabel: .init(text: "Back to home", color: ink),
            primaryButtonBackgroundColor: RGB(hex: 0xFFFDF7).uiColor
        )
    }
}

/// Draws the puck (accent circle, ink outline, hard shadow, "zzz") as the shield icon.
enum PuckIcon {
    static func image(casing: Casing) -> UIImage {
        let size = CGSize(width: 120, height: 128)
        return UIGraphicsImageRenderer(size: size).image { context in
            let ink = RGB(hex: 0x2A2722).uiColor
            let circle = CGRect(x: 1, y: 1, width: 118, height: 118)

            ink.setFill()
            UIBezierPath(ovalIn: circle.offsetBy(dx: 0, dy: 7)).fill()
            casing.accent.uiColor.setFill()
            UIBezierPath(ovalIn: circle).fill()
            ink.setStroke()
            let outline = UIBezierPath(ovalIn: circle.insetBy(dx: 0.75, dy: 0.75))
            outline.lineWidth = 1.5
            outline.stroke()

            let font = UIFont(name: "InstrumentSerif-Italic", size: 22) ?? .italicSystemFont(ofSize: 20)
            let text = NSAttributedString(string: "zzz", attributes: [.font: font, .foregroundColor: ink])
            let textSize = text.size()
            text.draw(at: CGPoint(x: circle.midX - textSize.width / 2, y: circle.midY - textSize.height / 2))
            _ = context
        }
    }
}
