# Technical Overview — reset

**Prepared for**: Project owner
**Prepared by**: Engineering
**Date**: 2026-10-01
**Version**: 1.1

---

## What Was Built

We've built the working foundation of **reset**, an iPhone app that puts your distracting apps to sleep when you tap your phone on a small NFC puck, and wakes them when you tap again.

Unlike a bare scaffold, the core loop works end to end:

- Pairing a puck
- Choosing a casing colour
- Choosing apps
- Tapping to rest and tapping to wake
- The timer, streak and emergency wakes

It follows the "Lab Notebook" design from the design handoff: graph paper, ink outlines, hard shadows, and serif headlines with code-style status lines.

There are two versions of the app, built from the same code:

- **ResetDemo** pretends to read the puck and pretends to block apps. It runs on your Mac's iPhone Simulator and on your phone with a free Apple ID, so you can try the whole flow today.
- **Reset** is the real thing. It reads your NTAG213 tags and blocks apps through Apple's Screen Time system. Apple only lets paid developer accounts use these features, so it needs your paid team.

---

## How to Run It Locally

### Prerequisites
- A Mac with Xcode 16 or newer
- Homebrew, then `brew install xcodegen`
- For the real version: an iPhone (iOS 17+), the paid developer team and an NTAG213 tag

### Setup Steps

1. Get the code:
   ```bash
   git clone https://github.com/erohryan/reset.git
   cd reset
   ```
2. Create your local config:
   ```bash
   cp Config.xcconfig.example Config.xcconfig
   # Fill in the values; see the table below
   ```
3. Generate the Xcode project (re-run whenever `project.yml` changes):
   ```bash
   xcodegen generate
   open Reset.xcodeproj
   ```
4. **Try the demo:** pick the **ResetDemo** scheme, choose an iPhone Simulator (or your phone with your free Apple ID as the team), and press Run. Tap the on-screen puck to "tap".
5. **Try it for real:** pick the **Reset** scheme, plug in your iPhone, set Signing → Team to the paid team for the app and both shield extensions, and press Run. On the pairing screen, tap the puck on screen, then hold the top of the phone to your tag.

### Configuration
| Setting | Description | Example |
|---|---|---|
| `DEVELOPMENT_TEAM` | Your Apple team ID | `AB12CD34EF` |
| `BUNDLE_ID_PREFIX` | Unique prefix for app IDs | `com.yourname` |
| `APP_GROUP_ID` | Lets the app and its shield screen share data | `group.com.yourname.reset` |

---

## What's Included

### Pucks and NFC
When you pair a tag, reset reads its built-in serial number and writes a random secret code onto it. Only that exact tag can then wake your apps. A copied serial number alone won't work, and neither will another puck. The tag can also carry its casing colour, so a Sage puck can turn the app Sage.

### Many pucks, paired once
Pair a puck in each place you use one (desk, bedside, car). Pairings are saved in your iCloud Keychain, so they survive reinstalling reset and appear on your other iPhones. **Any** of your pucks rests or wakes your apps. A puck can be shared too: a partner's phone can pair the same bedside puck, and both phones keep working.

### Tap-only
After pairing, reset walks you through a one-time **Shortcuts** automation for that puck. From then on you just tap the puck with your phone unlocked, even with reset closed. Apple doesn't let apps create the automation themselves, which is why there's a setup step. The trade-off: the automation can't check the puck's secret code, and someone could run "Rest or wake" from the Shortcuts app without a puck. That's about as easy as deleting the app, which already clears the blocks.

### Quick settings
On the home screen, tap an app to keep it awake on the next rest, and tap again to include it. Apps you rest most often come first. (iOS doesn't let apps read your Screen Time numbers or know which app is which, so your own history is what's used.)

### Letting certain people through
Blocked apps can still send notifications. The tap-only guide includes an optional step: create a "reset" Focus that only allows the people you choose (Messages, calls, and apps that support it, like WhatsApp), and have the puck automation switch it on and off with your rest.

### Blocking
Real blocking uses Apple's Screen Time framework. iOS itself enforces it, so it works even when reset is closed. When you open a resting app, iOS shows reset's shield: "Shh. Instagram is napping." with how long you've been reset and a "Back to home" button.

### Storage
Everything stays on the phone: your puck, your apps and your rest history live in one small file. Your remaining emergency wakes are stored in the iPhone Keychain, so reinstalling an update doesn't reset them.

### Screens
1. **Welcome:** "Give your apps a nap."
2. **Pair puck:** hold the phone to the puck, name it, and choose a casing colour.
3. **Pick apps:** "What should nap?" (Apple's app picker in the real version).
3b. **Tap-only setup:** the Shortcuts automation guide, with the optional Focus step.
4. **Ready:** the puck, your apps (tap to keep one awake), streak, and time rested today.
5. **Resting:** soft background, live timer, napping apps, and a quiet "lost your puck?" link.
6. **Shield preview:** tap a napping app to see what you'd see if you opened it.
7. **Wake:** "Good morning, apps." with the duration and the week's streak dots.
8. **Settings:** your pucks (rename, colour, tap-only setup, forget), pair another puck, apps, emergency wakes left, erase everything.

### Tests
28 automated tests cover the rules that matter: pairing, many pucks, shared pucks, remembering pucks after a reinstall, rest and wake by any puck, the Shortcuts toggle, quick toggles and their sorting, rejecting the wrong puck, limiting emergency wakes, streak maths, colours matching the design, and the puck data fitting on an NTAG213. All pass.

---

## What This Is Not (Yet)

- **Tested with real tags and blocking:** the real version compiles, but it still needs a run on your iPhone with your NTAG213 tags. This is the next step.
- **Multiple modes, schedules and minimum rest times:** not built. The design calls for one set of apps.
- **Real Screen Time usage figures:** "today" and "avg" show time *rested*, not phone usage.
- **Web dashboard and pool stats:** not built. These need a server and accounts.
- **Parent or school mode:** designed for, not built.
- **App Store release:** needs Apple's approval for distributing the Family Controls (app blocking) capability.

---

## Recommended Next Steps

### 1. Test on your iPhone with a real tag
*Why first:* NFC, blocking and the Shortcuts automation can't be tested in the Simulator. This proves the core loop on hardware, including that "Rest or wake" can block apps in the background and that WhatsApp respects the Focus allowed-people list.
Estimated effort: half a day (mostly signing setup).

### 2. Request the Family Controls distribution entitlement
*Why second:* Apple's review can take days to weeks, and TestFlight is blocked until it's approved. Your friend (as Account Holder) submits it at developer.apple.com.
Estimated effort: 30 minutes to submit, then waiting.

### 3. Design polish
*Why third:* app icon, tighter headline line height, a lock and wake animation, and checking how real app icons look inside the tiles.
Estimated effort: 2–4 days.

### 4. TestFlight beta with friends
Estimated effort: 1 day once the entitlement is approved.

---

## Infrastructure Recommendations

### For Development (Current State)
Runs on your Mac and iPhone. No cloud costs. The paid Apple Developer Program costs $99 a year.

### For Staging / Preview
TestFlight (free with the developer account) for up to 10,000 testers.

### For Production Launch
App Store only. No servers are needed while reset stays on the device.

### When You'll Need to Revisit
When you build the web dashboard or "pool" stats. That needs user accounts, a small backend (Supabase is a good fit), and a privacy policy covering what's shared.

---

## Design Notes

### Adopted in This Scaffold
- Lab Notebook tokens (colours, radii, borders, offset shadows, spacing) from `tokens.json`
- Casing → accent theming, with exact preset colours and a formula for custom hues
- Instrument Serif, Figtree and JetBrains Mono bundled with the app
- Graph-paper backgrounds, the Soft resting background, the puck with its dashed resting ring and NFC ping animation
- Ink buttons that sink into their shadow when pressed, the ink toggle, app tiles, pill stats and streak dots
- 350ms screen transitions, haptics on rest and wake, light mode only
- The playful copy voice ("nap", "rest", "wake")

### Deferred for Later
- App icon and puck product renders
- Headline line height of 0.95: SwiftUI on iOS 17 can't tighten below the font's natural line height, so headlines are slightly airier than the design
- The system shield can't use custom fonts or graph paper (an Apple limit). The in-app preview matches the design exactly.
- Web dashboard (design option 2c)

---

## Questions & Open Items

| # | Question | Who Needs to Answer |
|---|---|---|
| 1 | Will your friend's team submit the Family Controls distribution request? | You and your friend |
| 2 | Should emergency wakes ever renew (for example 3 a month), or stay lifetime? | You |
| 3 | Should pucks be pre-programmed with their colour before they ship? | You |

---

*Document prepared as part of the project scaffold. For technical details, refer to `docs/engineering-brd.md`.*
