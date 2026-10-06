import SwiftUI

// MARK: Text

/// "reset", always lowercase serif italic.
struct Wordmark: View {
    var size: CGFloat = 26
    var body: some View {
        Text("reset").font(RFont.display(size))
    }
}

/// Code-style status line in the casing ink, e.g. "// resting".
struct StatusLine: View {
    var text: String
    var size: CGFloat = 12
    @Environment(\.casing) private var casing

    var body: some View {
        Text(text)
            .font(RFont.mono(size))
            .foregroundStyle(casing.ink.color)
            .contentTransition(.opacity)
            .animation(.easeOut(duration: 0.2), value: text)
    }
}

struct Headline: View {
    var text: String
    var size: CGFloat = 40
    var body: some View {
        Text(text)
            .font(RFont.display(size))
            .lineSpacing(-size * 0.12)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct BodyText: View {
    var text: String
    var size: CGFloat = 15
    var body: some View {
        Text(text)
            .font(RFont.body(size))
            .foregroundStyle(Theme.body)
            .lineSpacing(size * 0.4)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: Buttons

/// Full-width pill with an ink border and a 4pt offset shadow. Sinks into its shadow when pressed.
struct InkButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    var kind: Kind = .primary
    @Environment(\.casing) private var casing
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        configuration.label
            .font(RFont.button)
            .foregroundStyle(Theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .inkSurface(Capsule(), fill: kind == .primary ? casing.accent.color : Theme.paper)
            .offset(y: pressed ? Theme.Shadow.m - 1 : 0)
            .background(Capsule().fill(Theme.ink).offset(y: Theme.Shadow.m))
            .padding(.bottom, Theme.Shadow.m)
            .opacity(isEnabled ? 1 : 0.35)
            .animation(.easeOut(duration: 0.08), value: pressed)
    }
}

extension ButtonStyle where Self == InkButtonStyle {
    static var primary: InkButtonStyle { InkButtonStyle(kind: .primary) }
    static var secondary: InkButtonStyle { InkButtonStyle(kind: .secondary) }
}

/// Small mono text button, e.g. "← back".
struct MonoLink: View {
    var title: String
    var action: () -> Void
    var body: some View {
        Button(title, action: action)
            .font(RFont.label)
            .foregroundStyle(Theme.subtle)
            .buttonStyle(.plain)
    }
}

// MARK: Puck

/// The hero object. Accent fill, ink border, 7pt shadow, serif label.
/// Resting adds a dashed ink ring; reading adds the NFC ping ring.
struct PuckView: View {
    var label: String = "tap"
    var size: CGFloat = 150
    var resting = false
    var reading = false
    var casingOverride: Casing?
    @Environment(\.casing) private var environmentCasing

    private var casing: Casing { casingOverride ?? environmentCasing }

    var body: some View {
        ZStack {
            if resting {
                Circle()
                    .strokeBorder(casing.ink.color, style: StrokeStyle(lineWidth: Theme.border, dash: [5, 4]))
                    .padding(-14)
                    .opacity(0.5)
            }
            if reading { PingRing(color: casing.ink.color) }
            Text(label)
                .font(RFont.display(size * 0.16))
                .foregroundStyle(Theme.ink)
                .frame(width: size, height: size)
                .inkSurface(Circle(), fill: casing.accent.color, shadow: Theme.Shadow.puck)
                .contentTransition(.opacity)
                .animation(.easeOut(duration: 0.2), value: label)
        }
        .frame(width: size, height: size)
        .padding(.bottom, Theme.Shadow.puck)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Puck")
        .accessibilityValue(label)
        .accessibilityAddTraits(.isButton)
    }
}

/// 2pt ring scaling 1→1.9 while fading .7→0 over 1.1s ease-out, looping.
struct PingRing: View {
    var color: Color
    private let period = 1.1

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period) / period
            let eased = 1 - pow(1 - t, 3)
            Circle()
                .strokeBorder(color, lineWidth: 2)
                .scaleEffect(1 + 0.9 * eased)
                .opacity(0.7 * (1 - eased))
        }
        .allowsHitTesting(false)
    }
}

// MARK: Controls

/// 42×24 pill toggle with a 17pt knob.
struct InkToggleStyle: ToggleStyle {
    @Environment(\.casing) private var casing

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 12) {
                configuration.label
                Spacer(minLength: 0)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule().fill(configuration.isOn ? casing.accent.color : Theme.paper)
                    Circle()
                        .fill(Theme.paper)
                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.border))
                        .frame(width: 17, height: 17)
                        .padding(.horizontal, 2)
                }
                .frame(width: 42, height: 24)
                .overlay(Capsule().strokeBorder(Theme.ink, lineWidth: Theme.border))
                .animation(.easeOut(duration: 0.2), value: configuration.isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Ink-bordered paper pill with a serif value and mono caption, e.g. "3h 12m today · avg 2h 41m".
struct PillStat: View {
    var value: String
    var caption: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(value).font(RFont.display(20))
            Spacer()
            Text(caption).font(RFont.caption).foregroundStyle(Theme.subtle)
        }
        .padding(.vertical, 9)
        .padding(.horizontal, 16)
        .inkSurface(Capsule())
    }
}

/// Small mono pill, e.g. the streak "12 days" on the home header.
struct MonoChip: View {
    var text: String
    var body: some View {
        Text(text)
            .font(RFont.caption)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .inkSurface(Capsule())
    }
}

/// Seven 24pt circles, M–S, filled with the accent on days with a rest.
struct StreakDots: View {
    var days: [Bool]
    @Environment(\.casing) private var casing
    private let labels = ["M", "T", "W", "T", "F", "S", "S"]

    var body: some View {
        HStack {
            ForEach(Array(labels.enumerated()), id: \.offset) { index, label in
                VStack(spacing: 4) {
                    Circle()
                        .fill(days[safe: index] == true ? casing.accent.color : .clear)
                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.border))
                        .frame(width: 24, height: 24)
                    Text(label).font(RFont.mono(10)).foregroundStyle(Theme.subtle)
                }
                if index < labels.count - 1 { Spacer(minLength: 0) }
            }
        }
    }
}

/// Casing swatches for picking a puck colour.
struct CasingPicker: View {
    @Binding var selection: Casing

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Casing.presets) { casing in
                Button {
                    selection = casing
                } label: {
                    Circle()
                        .fill(casing.accent.color)
                        .overlay(Circle().strokeBorder(Theme.ink, lineWidth: Theme.border))
                        .frame(width: 28, height: 28)
                        .padding(3)
                        .overlay {
                            if casing == selection {
                                Circle().strokeBorder(Theme.ink, style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(casing.name)
                .accessibilityAddTraits(casing == selection ? .isSelected : [])
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
