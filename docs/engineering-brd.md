# Engineering BRD — reset

**Version**: 1.1
**Date**: 2026-10-01
**Status**: Draft
**Prepared by**: Principal Engineer (via project-scaffold)

---

## 1. Project Overview

### 1.1 Summary
reset is an iPhone app that pairs with a cheap NFC "puck" (an NTAG213 tag in a 3D-printed casing). The user chooses a set of distracting apps. Tapping the phone on the puck puts those apps to sleep ("rest") using Apple's Screen Time APIs. Tapping the same puck again wakes them. Because the off-switch lives in a physical object, undoing the decision takes deliberate effort. That breaks the reflexive open-and-scroll loop. A small, non-renewable allowance of emergency wakes covers a lost puck. v1 is for individuals restricting their own phone. The architecture leaves room for a parent or school mode.

### 1.2 Application Type
Mobile, native iOS app with two app extensions.

### 1.3 Tech Stack
| Layer | Choice | Rationale |
|---|---|---|
| Language / Runtime | Swift (Swift 5 language mode), iOS 17+ | Screen Time and Core NFC are native-only frameworks |
| Framework | SwiftUI + Observation (`@Observable`) | Native, no dependencies; every Lab Notebook visual is achievable |
| Database | None (on-device JSON file in the App Group container) | State is tiny (one puck, one app set, session history) |
| ORM / Query Layer | `Codable` | Simpler and more testable than SwiftData for this size; shareable with extensions |
| Authentication | None (no accounts). Device-level: FamilyControls `.individual` authorisation | No server in v1 |
| UI / Styling | Custom Lab Notebook design system (`Reset/DesignSystem`), bundled OFL fonts | Implements `design_handoff_reset_mobile` |
| Hosting Target | App Store / TestFlight (paid team) | |
| Project generation | XcodeGen (`project.yml`) | Readable target and extension config, no project-file merge conflicts |

---

## 2. Requirements

### 2.1 Functional Requirements
- FR-001: The app shall pair a generic NTAG21x tag by reading its UID and writing a secret (plus casing hue) as an NDEF MIME record (`application/vnd.reset.puck`). If the tag already carries a reset secret, it is kept, not replaced.
- FR-002: Pairing is once per puck and remembered permanently. Pucks are stored in the iCloud Keychain (synchronizable), surviving reinstalls and syncing to the user's other devices.
- FR-003: The user can pair any number of pucks, each with a name ("Desk", "Bedside") and a casing. Re-pairing a known puck updates it instead of duplicating it.
- FR-004: One puck can be paired by several devices (FR-001 keeps the shared secret).
- FR-005: **Any** paired puck rests apps from Ready and wakes them from Resting. The last puck tapped themes the app.
- FR-006: Tap-only: a "Rest or wake" App Intent (`openAppWhenRun = false`) toggles reset in the background. A guided screen walks the user through a one-time Shortcuts NFC automation per puck (Run Immediately). It returns `resting` or `awake`.
- FR-007: The in-app tap remains as a fallback and performs the full UID + secret check. Unpaired or secret-less tags are rejected with "// not your puck".
- FR-008: Quick settings: on Ready, tapping an app tile keeps that app awake on the next rest (persisted). Tiles are sorted by how often the user has rested each app. Resting with every app switched off is refused.
- FR-009: Optional Focus integration: the tap-only guide explains creating a "reset" Focus with allowed people and switching it from the same automation using the intent's result.
- FR-010: The user has 3 lifetime emergency wakes, reachable only via "lost your puck?" on the resting screen. They don't count toward the streak.
- FR-011: Opening a resting app shows a reset-branded shield: "Shh. {App} is napping." with the rest duration and a "Back to home" button that closes the app.
- FR-012: Home shows streak, time rested today and the 14-day average. Wake shows duration, streak and Monday–Sunday dots.
- FR-013: Resting state survives relaunch, and the app reloads state on foreground (changes made by the Shortcuts automation).
- FR-014: Settings: per-puck rename, casing, tap-only setup and forget (the last puck can't be forgotten while resting), plus pair another puck, change apps, emergency wakes left, and erase everything (blocked while resting).

### 2.2 Non-Functional Requirements
- NFR-001: Blocking is enforced by iOS (ManagedSettings), not by the app being open.
- NFR-002: The puck secret never leaves the tag in plain text. The app stores SHA-256(UID ‖ secret) only.
- NFR-002b: The Shortcuts path can't verify which tag fired it, and the intent can be run manually from the Shortcuts app. This bypass is accepted as equivalent in effort to deleting the app.
- NFR-003: The emergency wake counter is stored in the Keychain, so it survives app updates.
- NFR-004: No network access, analytics or accounts in v1.
- NFR-005: All rest/wake rules live in `LockEngine` behind injected protocols and are unit-tested on mocks.
- NFR-006: The UI matches `design_handoff_reset_mobile` within iOS platform limits (see 2.3).

### 2.3 Explicit Out of Scope
- Several named modes (the design uses one app set; the model can grow)
- Schedules and minimum rest times (need a DeviceActivityMonitor extension)
- Real Screen Time usage stats or sorting by usage: iOS sandboxes this data inside a DeviceActivityReport extension that can't pass anything back to the app
- Sorting by popular choices across users: app tokens are opaque, so reset can't know which app is which
- Filtering notifications by contact inside reset (delegated to an iOS Focus)
- Web dashboard and pool/aggregate data (needs a backend and accounts)
- Parent / school mode (`.child` authorisation)
- Android
- App icon, final illustrations, product renders of the puck
- **Platform limits:** the system shield can't use custom fonts, textures or a live timer. App picking must use Apple's picker. Core NFC always shows the system "Ready to Scan" sheet.

---

## 3. Data Model

### 3.1 Entity Relationship Diagram

~~~mermaid
erDiagram
    RESET_STATE ||--o{ PUCK : "pairs (Keychain)"
    RESET_STATE ||--|| NAP_SELECTION : "rests"
    RESET_STATE ||--o{ REST_SESSION : "records"
    PUCK ||--o{ REST_SESSION : "starts / ends"
    PUCK {
        uuid id PK
        string name
        bool tapOnlyReady
        string tagHash
        Casing casing
        date pairedAt
    }
    NAP_SELECTION {
        FamilyActivitySelection family
        DemoApp[] demoApps
    }
    REST_SESSION {
        uuid id PK
        uuid puckID FK
        date startedAt
        date endedAt
        bool emergency
        NapSelection rested
    }
    RESET_STATE {
        NapSelection skipped
        uuid themePuckID
        Puck[] pucks
        NapSelection selection
        RestSession[] sessions
    }
~~~

### 3.2 Data Dictionary

#### Puck
| Field | Type | Nullable | Description |
|---|---|---|---|
| id | UUID (PK) | No | Local identifier |
| name | String | No | Where it lives, e.g. "Desk" |
| tagHash | String (hex SHA-256) | No | Hash of tag UID + secret |
| tapOnlyReady | Bool | No | User has set up the Shortcuts automation |
| casing | Casing {name, hue, isNeutral} | No | Theme colour |
| pairedAt | Date | No | When paired |

**Relationships:** has many RestSession.

#### NapSelection
| Field | Type | Nullable | Description |
|---|---|---|---|
| family | FamilyActivitySelection | No | Apple's opaque app, category and web tokens |
| demoApps | [DemoApp] | No | Placeholder apps (demo build only) |

#### RestSession
| Field | Type | Nullable | Description |
|---|---|---|---|
| id | UUID (PK) | No | |
| puckID | UUID (FK → Puck) | Yes | Puck that started the rest (nil when started from Shortcuts) |
| startedAt | Date | No | |
| endedAt | Date | Yes | Nil while resting |
| emergency | Bool | No | Ended by emergency wake |
| rested | NapSelection | Yes | What napped; drives quick-toggle sorting |

#### Outside the JSON file
| Store | Key | Description |
|---|---|---|
| iCloud Keychain | `reset.pucks` | Paired pucks (source of truth) |
| Keychain | `reset.emergency.remaining` | Emergency wakes left (default 3) |
| App Group UserDefaults | `reset.casing`, `reset.restingSince` | Read by the shield extension |
| NFC tag (NDEF) | `{"v":1,"s":<secret>,"h":<hue>}` | ~60 bytes; fits NTAG213 (144 bytes) |

---

## 4. API Surface

### 4.1 Endpoint Index
Not applicable. reset v1 has no server. The internal "API" is `LockEngine`:

| Method | Description |
|---|---|
| `startPairing()` / `pairTap()` / `chooseCasing(_:)` / `confirmPuck()` | Pairing flow |
| `requestAuthorization()` / `saveSelection(_:)` | Screen Time permission and app choice |
| `puckTap()` | In-app tap: rest from Ready, wake from Resting |
| `toggleFromShortcut()` | Used by the Rest or wake App Intent |
| `toggleSkipped(_:)` / `quickToggleItems()` | Home-screen quick settings |
| `renamePuck` / `changeCasing` / `removePuck` / `showTapSetup(for:)` | Puck management |
| `emergencyWake()` | Limited wake without the puck |
| `restedToday()` / `dailyAverage()` / `streak()` / `weekDots()` | Stats |

### 4.2 Authentication Model
No user accounts. The device owner grants FamilyControls `.individual` authorisation (Face ID / passcode). The puck itself is the "credential" for waking apps: UID + secret, verified by hash.

### 4.3 Webhook Surface
Not applicable.

---

## 5. Infrastructure Recommendations

### 5.1 Hosting
App Store distribution under the paid team. Before any TestFlight build, the Account Holder must request the **Family Controls (Distribution)** entitlement from Apple. Approval can take days to weeks. Development builds work immediately.

### 5.2 Database
None for v1. When the web dashboard arrives, add a backend (for example Supabase or a small API on Postgres) with opt-in, anonymised session sync.

### 5.3 File Storage
Not applicable.

### 5.4 Email
Not applicable.

### 5.5 CI/CD Recommendation
GitHub Actions on a macOS runner: `brew install xcodegen && xcodegen generate && xcodebuild test -scheme ResetDemo`. Add Xcode Cloud or fastlane for TestFlight once distribution entitlements are approved.

### 5.6 Scaling Considerations
The first bottleneck is product, not infrastructure: syncing sessions for the dashboard and pool stats needs accounts, a backend and a privacy policy. On device, session history grows by about 100 bytes per rest, which is fine for years. Archive or summarise if it ever matters.

---

## 6. Security Baseline
- [x] `Config.xcconfig` (team ID, bundle IDs) gitignored; example committed
- [x] Puck secret stored only on the tag; app stores a hash
- [x] Emergency counter in Keychain (`AfterFirstUnlock`)
- [x] State file written with `completeFileProtectionUntilFirstUserAuthentication`
- [ ] Known limit: with `.individual` authorisation, deleting the app removes all shields (an iOS platform limit for any self-authorised blocker). A parent mode (`.child`) closes this.
- [ ] Known limit: an attacker who can read the tag can clone it (NTAG213 has no secure element). Acceptable for a self-control device. NTAG 424 DNA would add cryptographic authentication.
- [ ] Privacy nutrition label: "Data not collected"

---

## 7. Open Questions
| # | Question | Owner | Target Resolution |
|---|---|---|---|
| 1 | Who submits the Family Controls distribution request (friend's team as Account Holder)? | Product owner | Before first TestFlight |
| 2 | Should the 3 emergency wakes ever renew (for example monthly)? | Product owner | Before public beta |
| 3 | Should pucks be pre-programmed with their casing hue at manufacture? | Product owner | Before printing a batch |
| 4 | Final app icon and puck product render | Design | Before App Store |

---

## 8. Revision History
| Version | Date | Author | Changes |
|---|---|---|---|
| 1.0 | 2026-10-01 | Principal Engineer | Initial scaffold BRD |
| 1.1 | 2026-10-01 | Principal Engineer | Many pucks, shared pucks, permanent pairing, tap-only via Shortcuts, quick toggles, Focus guidance |
