# WalkCue — Portfolio Audit Ship Notes

**Date:** 2026-05-15
**Audit:** 04-walkcue.md (0 HARD · 4 SIGNIFICANT · 4 POLISH)

## Summary
0 HARDs fixed (none reported), 4 SIGNIFICANTs fixed (S1 deferred to ASC copy edit; S2/S3/S4 code-fixed), 3 POLISH fixed (P1, P2 implicitly via S3, P3), 1 POLISH deferred (P4).

## Fixes applied

- **S2 — "one-time purchase" copy** — fixed in `WalkCue/Features/Settings/SettingsView.swift` (premium upsell row now reads `"Pick monthly, yearly, or lifetime."`) and `WalkCue/Features/Start/StartView.swift:172` (UpsellCard footer now reads `"Unlock Premium"`).
- **S3 — manage-subscriptions deep link** — added in `WalkCue/Features/Settings/SettingsView.swift` premium section: when `purchases.isPremium`, a `"Manage subscription"` button calls `AppStore.showManageSubscriptions(in:)` on the active `UIWindowScene` (falls back to `apps.apple.com/account/subscriptions` URL). Restore button now also visible to subscribed users.
- **S4 — analytics opt-out toggle** — added a `Privacy` section in `SettingsView` with `Toggle("Share anonymous analytics", isOn: analyticsEnabledBinding)`, backed by `@AppStorage("portfolio.analytics.opted_out")` and wired to `PortfolioAnalytics.shared.optOut()` / `optIn()` (Pattern A from FIX_GUIDELINES).
- **P1 — cues footer text** — `SettingsView.swift` cues footer now says interval cues play "while the app is open" rather than "at each interval transition."
- **P2 — disclosureManage paired with in-app link** — implicitly resolved by S3; in-app Manage Subscription row now backs the legal block's "Account Settings" reference.
- **P3 — completion notification title/body** — `BackgroundCompletionNotifier.swift:93-99` now uses `title: "Walk complete"` / `body: "<N> minute(s) done. Nice work."` (was `title: "WalkCue"`).

## Deferred / owner action required

- **S1 — ASC description edit required (NOT a code change).** Mid-walk per-interval cues are foreground-only (`WalkSession.swift:97-101` Timer pauses when backgrounded). Per FIX_GUIDELINES Pattern G and audit recommendation #3, the surgical path is to update the App Store description rather than re-architect with `UIBackgroundModes=audio` + AVAudioSession (which was *intentionally removed* per prior audit and would re-introduce reviewer scrutiny).

  **ASC edit needed:** in the App Store description, change the line claiming "haptic and audio cues at each transition" (or "Background completion alerts fire reliably" framing) to something like:
  > "Cues play with the app open; a local notification alerts you when your walk is complete, even with the screen off."

  If the owner instead wants always-on background cues as a product wedge, the work is: add `UIBackgroundModes=audio` to `project.yml`, configure `AVAudioSession` (`.playback`, `.mixWithOthers`) in `CueEmitter`, and schedule per-interval `UNTimeIntervalNotificationTrigger` requests from `WalkSession.start()`. ~1-2 hour change; flagged DEFERRED here per the no-StoreKit / no-architectural-rewrite rules and the 30-minute guideline.

- **P4 — free-tier reminder cap (`PricingConfig.freeReminderSlots = 1`) is dead code.** `SettingsView` only renders a single `walk_reminder` toggle, so the gate at `PremiumGate.swift:57-60` is unreachable by free users. DEFERRED — needs owner decision: either ship the additional reminder kinds the gate envisions (e.g., "post-walk stretch", "hydration", "weekly streak") or remove the gate. No surgical fix possible without product direction.

## Risk notes

- All code changes are scoped to UI / copy in `SettingsView.swift`, `StartView.swift`, and `BackgroundCompletionNotifier.swift`. No `PurchaseManager` plumbing, no SwiftData / persistence schemas, no IAP product IDs touched.
- `import StoreKit` added to `SettingsView.swift` for `AppStore.showManageSubscriptions(in:)`. StoreKit is already a project dependency (`PaywallView.swift`, `PurchaseManager.swift`).
- Analytics opt-out wiring uses the canonical `portfolio.analytics.opted_out` UserDefaults key — matches the key inside `PortfolioAnalytics.swift` so the toggle is consistent with what `optOut()` / `optIn()` persist internally.
- `showManageSubscriptions(in:)` requires iOS 15+. WalkCue's deployment target already exceeds this (StoreKit 2 `Transaction.updates` and `AppStore.sync()` are already used).
- No version bump, no `xcodebuild` run, no push.
