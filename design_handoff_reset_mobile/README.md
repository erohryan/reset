# Handoff: reset — Lab Notebook design system + mobile flow

## Overview
reset is a focus app. The user taps their phone on a physical NFC **puck** to lock ("nap") a chosen set of apps, and taps again to unlock them. It is mobile-first. A web dashboard comes later and will show personal metrics plus aggregate data across the user pool. The puck's casing colour sets the app's accent colour.

## About the design files
The files in this bundle are **design references made in HTML**. They are prototypes that show the intended look and behaviour, not production code. Recreate them in the target codebase's environment (React Native / Expo, SwiftUI, etc.) using its patterns. If there is no codebase yet, pick the framework that fits best. A cross-platform mobile stack such as Expo + React Native suits this app because it needs NFC (react-native-nfc-manager) and, on iOS, the Screen Time / FamilyControls APIs for app blocking.

Open `Reset Mobile Prototype.dc.html` in a browser to click through the flow. It needs `support.js` beside it.

## Fidelity
**High fidelity.** Colours, type, spacing, borders, shadows, copy and interactions are final. Recreate them pixel-accurately.

## Visual language ("Lab Notebook")
- Cream graph-paper backgrounds (20px grid).
- Ink outlines: 1.5px solid #2a2722 on cards, buttons, tiles and toggles.
- **Hard offset shadows** with no blur (`0 4px 0 #2a2722`), so elements look slightly raised.
- Serif italic (Instrument Serif) for headlines and the wordmark, Figtree for UI text, JetBrains Mono for data, status and timers.
- Status lines in code style: `// resting`, `// instagram.status = resting`.
- Copy voice is playful and calm: apps "nap", "rest" and "wake".

## Design tokens
See `tokens.json` for the full machine-readable set.

### Neutrals
| token | hex |
|---|---|
| paper (surfaces) | #fffdf7 |
| canvas | #f7f4ec |
| grid line | #f3eee2 |
| divider (dashed) | #e0d9c8 |
| muted | #9b9484 |
| subtle text | #7a7468 |
| body text | #4d483f |
| ink (text, borders, shadows) | #2a2722 |

### Casing → accent (the theming system)
Every casing uses the **same lightness and chroma; only the hue changes**. Any custom hue therefore stays calm, and the system scales to any number of casings.
- **Accent** = `oklch(0.78 0.095 H)`: puck, primary buttons, toggles on, chart fills. Text on the accent is always ink #2a2722.
- **Soft** = `oklch(0.95 0.035 H)`: background of the locked and shield screens, and chips.
- **Ink** = `oklch(0.42 0.12 H)`: status lines and tinted text.
- Graphite caps chroma at 0.012.

| casing | H | accent | soft | ink |
|---|---|---|---|---|
| Clay | 45 | #eba484 | #ffe8dc | #803200 |
| Sage | 155 | #85ca9d | #ddf6e4 | #005f2e |
| Iris | 280 | #abb1f4 | #e9edff | #42428c |
| Tide | 220 | #6bc6e1 | #d6f5ff | #005a7a |
| Graphite | 250 | #b2b8bf | #e9eff6 | #484e54 |

Default casing: **Clay**.

### Typography
| role | spec |
|---|---|
| Display XL | Instrument Serif italic 52/0.95 |
| Display L | Instrument Serif italic 46/0.95 |
| Display M (screen titles) | Instrument Serif italic 40/0.95 |
| Display S | Instrument Serif italic 28/1 |
| Wordmark "reset" | Instrument Serif italic 24–26, always lowercase |
| Timer L / M | JetBrains Mono 500 36 / 26 |
| Body | Figtree 400 15/1.5, colour #4d483f |
| Body S | Figtree 400 14/1.45 |
| Button | Figtree 600 16 |
| Label / status | JetBrains Mono 12, coloured with the casing ink |
| Caption | JetBrains Mono 11, #7a7468 |

### Radius
App tile 16 (11 in lists) · shield app tile 22 · cards 18–20 · buttons, chips and toggles: pill (999) · puck: circle.

### Borders and shadows
- Default border: 1.5px solid #2a2722
- Napping app tile: 1.5px **dashed** #9b9484 on rgba(255,253,247,.6), with glyph colour #b3ab98
- Offset shadows (no blur): S `0 3px 0 #2a2722`, M `0 4px 0`, L `0 5px 0`, puck `0 7px 0`

### Spacing
Screen padding: 64px top (below the status bar), 24–26px sides, 28–30px bottom. Vertical stack gap is 12–14px. Card padding is 12–16px.

## Components
- **Puck**: 150px circle (124–108px in smaller contexts). Accent fill, ink border, `0 7px 0` shadow. Its centre label is italic serif 24: "tap", "hello" once paired, or "zzz" while locked. While locked it gets an extra dashed ink ring at inset −14px, opacity .5.
- **NFC read ring**: a 2px ring in the casing ink. It scales 1→1.9 while fading .7→0 over 1.1s ease-out, looping only while the puck is being read.
- **Primary button**: full-width pill, 15px padding, accent fill, ink border, `0 4px 0` shadow, Figtree 600 16. Disabled state is opacity .35.
- **Secondary button**: same, with a #fffdf7 fill.
- **Toggle**: 42×24 pill with an ink border. Off fill is #fffdf7, on fill is the accent. The 17px knob has a paper fill and ink border and moves left 2→19px over 200ms.
- **App tile**: 52px rounded square (r16), ink border, paper fill, with a mono initial as a placeholder for the real app icon. The label below is Figtree 11. When napping, the border is dashed and muted, and a "z" badge (serif italic 14, ink border, paper pill) sits at top-right offset −7px.
- **App row** (picker): 36px tile, name in Figtree 500 15, toggle on the right, 1px dashed divider. Tapping the row toggles it.
- **Pill stat**: ink-bordered paper pill with a serif italic value and a mono caption.
- **Streak dots**: 7 × 24px circles with ink borders. Days completed are filled with the accent, other days are transparent. Labels below are M T W T F S S.

## Screens (phone: 360×760 design frame)
1. **Welcome**: wordmark at top-left. A centred 150px puck (static). `// a puck for your phone`. "Give your apps a nap." Body: "Tap your phone on the puck and the apps you choose go to sleep. Tap again to wake them." Primary button: **Pair a puck**.
2. **Pair puck (01 / 02)**: "← back" and the step count in mono. "Hold your phone to the puck." with the subline "The top of the phone works best." A centred puck, with a status line below it that cycles: "waiting for a tap" → "reading puck…" (ring animating) → "found it ✓". Once found, a card appears with an accent dot, "Your puck, {Casing}" and "id rs-04f2 · nfc ok". The **Continue** button stays disabled until the puck is found.
3. **Pick apps (02 / 02)**: "What should nap?" sits above an ink-bordered, scrollable list of app rows (Instagram, TikTok, X, YouTube, Reddit and Snapchat are on by default; Messages and Maps are off). The button reads "Rest N apps", or "Pick at least one" and disabled when none are selected.
4. **Ready (home)**: wordmark, plus a streak pill ("12 days") on the right. Puck labelled "tap". Status `// puck nearby` (or "reading puck…"). "Ready when you are." / "Hold your phone to the puck to rest N apps." A 4-column grid of the chosen apps, awake. A pill stat at the bottom: "3h 12m today · avg 2h 41m".
5. **Locked**: the background switches to **Soft** with an ink grid at 6% opacity. Status `// resting`. Puck labelled "zzz" with the dashed outer ring. "{N} apps napping" (or "waking everything…"). "You're reset." Live timer HH:MM:SS. A grid of napping tiles; tapping one opens its Shield. Hint: "tap an app to peek · tap the puck to wake".
6. **Shield** (shown when the user opens a napping app): Soft background. A 72px app tile with ink border and `0 5px 0` shadow. `// instagram.status = resting`. "Shh. Instagram is napping." "Reset for {timer}. Tap your phone on the puck to wake it." Secondary button **Back to home**, which returns to Locked.
7. **Unlocked**: `// all apps awake`. "Good morning, apps." "You were reset for" followed by the duration (mono 36). A streak card with "{N} days", "streak +1" and the week dots. Primary button **Done**, which returns to Ready.

## Interactions and state
```
step: welcome | pair | pick | home | locked | shield | wake
pair: idle | reading | done
reading: bool     // an NFC read is in progress; it ignores repeat taps
selectedApps: Set<string>
lockedAt: timestamp
lastDuration: ms
shieldApp: string
streak: number
casing: Clay | Sage | Iris | Tide | Graphite | custom hue
```
- An NFC tap on Ready → reading (the prototype simulates 1300ms) → Locked, with lockedAt = now.
- An NFC tap on Locked → reading → Unlocked, with lastDuration = now − lockedAt and streak + 1.
- Unlocking is **tap only**: there is no emergency unlock and no timer.
- Every screen enters with opacity 0→1 and translateY 6px→0 over 350ms ease-out.
- The timer ticks every 1s.
- In production, the puck tap is a real NFC read of the paired tag ID. Reject any tag that isn't paired.

## Web dashboard (direction only, see `Reset Design System.dc.html` option 2c)
- Tabs: You / Pool / Puck. Range pill: last_14d.
- KPI cards: Reset today, Streak, Daily avg, Unlocks.
- "Hours reset, daily": a 14-day bar chart with a dashed pool-average line.
- "What everyone rests": a bar list of the apps most often napped across the pool.
- Live pills: "2,431 resetting now", pool average, and your percentile. All pool figures are placeholders.

## Assets
There are no image assets. App icons are mono-initial placeholders; replace them with real app icons, which iOS FamilyControls provides as tokens/labels. The puck is a flat circle until there are product renders. Fonts are from Google Fonts: Instrument Serif, Figtree, JetBrains Mono.

## Files
- `Reset Mobile Prototype.dc.html`: the clickable mobile flow and the primary reference.
- `Reset Design System.dc.html`: the direction exploration. Lab Notebook is options 1c and 2c, which include the dashboard.
- `tokens.json`: the design tokens.
- `support.js`: the runtime needed to open the HTML files locally.
