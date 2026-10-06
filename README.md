# reset

App for slowing down and getting away from the social distractions that modern life has presented us.

Tap your phone on a puck and the apps you choose take a nap. Tap again to wake them.

Native iOS (SwiftUI, iOS 17+). A puck is any NTAG213/215/216 NFC tag, for example one in a 3D-printed casing. Design source of truth: `design_handoff_reset_mobile/`.

## Two app targets

| Target | NFC | App blocking | Signing |
|---|---|---|---|
| **ResetDemo** | Simulated (1.3s tap) | Simulated | Free Apple ID works. Runs in the Simulator. |
| **Reset** | Real (Core NFC) | Real (Screen Time) | Paid developer team. Physical iPhone only. |

Both share all code. `ResetDemo` is compiled with `RESET_DEMO`, which swaps in `MockTagReader` and `MockBlockingService`.

## Run it

Requires Xcode 16+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
cp Config.xcconfig.example Config.xcconfig   # set DEVELOPMENT_TEAM, BUNDLE_ID_PREFIX, APP_GROUP_ID
xcodegen generate
open Reset.xcodeproj
```

- **Simulator / free Apple ID:** choose the **ResetDemo** scheme and run. Tap the on-screen puck to simulate a tap.
- **Real puck:** choose the **Reset** scheme, select your iPhone, set the team to the paid team, and run. Hold the top of the phone to your NTAG213.

Tests run against the demo target:

```bash
xcodebuild -project Reset.xcodeproj -scheme ResetDemo \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```

### Design shortcuts (Debug, demo only)

Launch with `-seed ready`, `-seed skipped` or `-seed resting` (Scheme → Run → Arguments) to start on that screen with sample data. Add `-screen tapsetup` to open the tap-only guide.

## How tapping works

- **Pair once, remembered forever.** Pucks are stored in the iCloud Keychain, so they survive reinstalling the app and sync to your other iPhones.
- **Many pucks:** any of your pucks rests or wakes your apps. **Shared pucks:** pairing keeps a secret already on the tag, so several phones can trust one puck.
- **Tap-only:** each puck gets a one-time Shortcuts NFC automation that runs the **Rest or wake** App Intent (`Reset/App/RestOrWakeIntent.swift`). The in-app tap still works as a fallback.
- **Quick toggles:** tap an app tile on the home screen to keep it awake next time. Tiles are sorted by how often you rest them (iOS doesn't let apps read Screen Time usage).
- **Let people through:** optional Focus mode switched by the same automation (the intent returns `resting` or `awake`).

## Layout

```
Reset/App            Entry point, environment wiring (real vs mock services), root router, Rest or wake App Intent
Reset/Features       Screens: Onboarding (welcome, pair, pick, tap-only setup), Home, Locked, Wake, Settings
Reset/Core/NFC       TagReader protocol, Core NFC reader, mock
Reset/Core/Blocking  BlockingService protocol, Screen Time service, mock, NapSelection
Reset/Core/Lock      LockEngine: all rest/wake rules and stats
Reset/Core/...       JSON state store, Keychain emergency allowance, puck verification
Reset/DesignSystem   Lab Notebook tokens and components (puck, buttons, tiles, toggle…)
Shared               Casing colour engine + App Group state (app and shield extension)
ResetShield          System shield shown when a napping app is opened
ResetShieldAction    Shield "Back to home" button
ResetTests           LockEngine and casing tests
```

See `docs/technical-overview.md` for a walkthrough and `docs/engineering-brd.md` for the engineering spec.
