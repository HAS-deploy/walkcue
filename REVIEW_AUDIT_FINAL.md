# WalkCue — Adversarial App Store Review Audit (FINAL)

**Run date:** 2026-04-17
**Reviewer persona:** Apple App Store Review
**Target:** `/Users/tony/Developer/walkcue` @ current HEAD
**ASC app ID:** 6762468976
**State:** WAITING_FOR_REVIEW; reviewer notes + demo video attached.
**Verdict:** **2 HARD, 4 SIGNIFICANT.** Do NOT let the current submission review without fixes.

## HARD

### H1 — 2.5.1 / 5.1.1 — HealthKit used without entitlement
- `HealthKitManager.swift:3,12,28` calls `HKHealthStore()` + `requestAuthorization`.
- No `*.entitlements` anywhere; `project.yml` has no `CODE_SIGN_ENTITLEMENTS`; `project.pbxproj` has none.
- **Impact:** in production the authorization sheet never appears; reviewer hits dead feature → 2.1 bounce.
- **Fix (simplest for v1):** strip HealthKit from v1. Remove the import, the manager, the Settings toggle, and `NSHealthShareUsageDescription`/`NSHealthUpdateUsageDescription` from `project.yml`. Advertise "Apple Health support coming soon" in description if desired, or just omit entirely.

### H2 — 2.5.4 — `UIBackgroundModes=audio` declared but never produces background audio
- `Info.plist:31-34` + `project.yml:44-45` declare `audio`.
- `CueEmitter.swift:54,69` uses `AudioServicesPlaySystemSound` — does NOT play in background.
- No `AVAudioSession` setup anywhere.
- **Fix (simplest):** remove `UIBackgroundModes` entirely — cues only fire with app on-screen, which is honest.

## SIGNIFICANT

### S1 — 5.1.1 / 2.3.1 — `NSHealthUpdateUsageDescription` promises workout saves that never happen
Cleared by H1 fix.

### S2 — 2.3.1 / 3.1.1 — Paywall lists non-existent features
- `PricingConfig.swift:13` "Advanced cue packs" — no cue pack feature in code.
- `PricingConfig.swift:16` "Saved presets and favorites" — no preset/favorite feature in code.
- **Fix:** remove both lines. Delete orphan `PremiumFeature.advancedCues` + its test.

### S3 — 3.1.1 — Paywall missing EULA + Privacy Policy links
- `PaywallView.swift:106-113` legal footer has neither.
- **Fix:** add `Link("Terms of Use (EULA)", ...)` to Apple standard EULA URL + `Link("Privacy Policy", ...)` to the Pages URL.

### S4 — 2.1 — Double history-insert race on session end
- `WalkSessionView.swift:25` `onChange(.finished) → finalize()` + button paths both call `history.add`.
- **Fix:** remove the `.onChange` `finalize()` path; buttons are the single write.

## Prioritized fix list
1. **H1** — strip HealthKit from v1 (fastest path; keeps scope safe).
2. **H2** — remove `UIBackgroundModes=audio`.
3. **S2** — remove 2 imaginary paywall benefits.
4. **S3** — add EULA + Privacy links to paywall footer.
5. **S4** — fix double history-insert.
6. Regenerate project, re-archive, re-upload, cancel current submission, submit new build.
