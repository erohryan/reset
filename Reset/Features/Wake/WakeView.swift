import SwiftUI

/// 7. Unlocked. "Good morning, apps."
struct WakeView: View {
    @Environment(LockEngine.self) private var engine

    var body: some View {
        let emergency = engine.lastRest?.emergency == true
        ScreenFrame {
            StatusLine(text: emergency ? "// woken early" : "// all apps awake")
            Headline(text: "Good morning, apps.", size: 52)
            BodyText(text: "You were reset for")
            Text(DurationFormat.clock(engine.lastRest?.duration ?? 0))
                .font(RFont.timerL)
                .monospacedDigit()

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    Text("\(engine.streak()) days").font(RFont.display(30))
                    Spacer()
                    StatusLine(text: emergency ? "emergency wakes don't count" : "streak +1", size: 11)
                }
                StreakDots(days: engine.weekDots())
            }
            .padding(16)
            .inkCard(radius: Theme.Radius.cardL)

            Button("Done") { engine.finishWake() }
                .buttonStyle(.primary)
        }
    }
}
