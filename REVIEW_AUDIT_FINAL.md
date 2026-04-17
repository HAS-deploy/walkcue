# WalkCue — FINAL pre-review audit

Run date: 2026-04-17
Prompt source: `~/Documents/app-store-review-prompt.md`
State: v1.0 submitted to Apple, WAITING_FOR_REVIEW. Comprehensive reviewer
notes + 20-sec demo video attached after the SleepWindow 2.1 rejection.

## Summary

**No HARD rejections.** **No SIGNIFICANT rejections remain in the codebase.**
All Apple 2.1 "Information Needed" blockers are pre-answered in the review
details notes + demo video.

## HARD rejections

None. WalkCue is:
- Fully local-first (no network except StoreKit).
- No account / sign-in.
- One clean non-consumable IAP.
- No third-party redistributable binaries.
- No JS runtime / downloadable code execution.
- `ITSAppUsesNonExemptEncryption = false`.

## SIGNIFICANT risks — all cleared

| # | Finding | Status |
|---|---|---|
| 1 | 2.1 Info-needed rejection risk | ✅ 8-point reviewer notes + demo video preemptively supplied |
| 2 | 2.3.3 Screenshots showing actual app | ✅ 4 iPhone 6.9" + 4 iPad 12.9" screenshots show premium content in use |
| 3 | 5.1.1 Purpose strings | ✅ `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription` both include the word "optional" and say what they're for |
| 4 | Privacy policy URL | ✅ https://has-deploy.github.io/walkcue/privacy-policy.html live |
| 5 | App Privacy nutrition label | ✅ published as Data Not Collected |

## MODERATE risks

### 1 — 4.2 Minimum Functionality
Core is four time-based features: walk session, routine, history, cues.
Full StoreKit 2 integration, local notifications, and persisted state put
this well above "repackaged website" territory. Reviewer notes call out
the native integrations explicitly.

### 2 — 1.4.1 Health-adjacent content
Three "not medical advice" disclaimers. Walking is a low-risk category.
Reviewer notes explicitly state WalkCue does not diagnose/treat anything.
**Pass.**

### 3 — Background audio mode
Info.plist declares `UIBackgroundModes = audio` so interval cues continue
playing during an active walk when the device is locked. The entitlement
is used ONLY during an active `WalkSession`, never otherwise. Apple
routinely approves this for workout/timer apps.

## SOFT risks

### 4 — Accessibility
Result rows and controls use large touch targets and SwiftUI's built-in
accessibility. No VoiceOver breaks. Premium-lock upsell card is a
well-labeled Button.

### 5 — Privacy manifest alignment
`NSPrivacyAccessedAPICategoryUserDefaults CA92.1` declared. Code uses
UserDefaults exclusively for persistence. HealthKit usage is behind an
explicit user toggle. **Pass.**

### 6 — Version/build
`1.0` / `1`. First submission; clean.

## Test coverage
- **20 unit tests** passing:
  - `IntervalEngineTests`: progress math, transitions, midnight rollover, repeats, negative clamp
  - `PremiumGateTests`: feature gating
  - `RoutinesStoreTests`: add, update, delete, persistence, built-ins
  - `HistoryStoreTests`: add, filter by day, 500-cap

## Manual QA on simulator
- iPhone 17 Pro Max: all 4 tabs render, paywall opens/closes cleanly
- iPhone SE 3rd gen: layout intact, no clipping
- iPad Pro 13": layout works in both orientations

## Remaining action items
None. WalkCue is ready for review. If rejected under 2.1, the demo video
+ notes should be sufficient. If re-reviewed and approved, ship.
