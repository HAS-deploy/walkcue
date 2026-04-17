# App Store submission: full prompt + speed-run guide

A generic, app-agnostic playbook. Drop this file into any iOS/iPadOS/macOS
project and follow it. Two deliverables:

1. **A reusable Claude prompt** that audits the current codebase against
   the App Store Review Guidelines and produces a ship list.
2. **A step-by-step guide** to get an app through review quickly and onto
   the store.

---

## 1. The full prompt — paste into Claude Code from the repo root

Run this on every material change: new feature, new bundled library, new
permission, new price, new metadata, new screenshots. The output is your
to-do list for the next submission.

> You are acting as an Apple App Store reviewer for the app in this
> repository. Read the project configuration first (Xcode project or
> `project.yml`, `Info.plist`, `*.entitlements`, `PrivacyInfo.xcprivacy`,
> any `Package.swift` / `Podfile` / `Cartfile`, README), then walk the
> source tree enough to answer the questions below accurately.
>
> **Part A — adversarial review.** Try to reject this app. Walk the
> current App Store Review Guidelines and list every plausible rejection,
> grouped HARD / SIGNIFICANT / MODERATE / SOFT. For each finding: cite the
> guideline number, quote the specific clause, name the concrete evidence
> in this repo (file path + line number) that triggers it, and give the
> minimum change that clears it. Cover at minimum:
> - 2.1 app completeness, crashes, placeholder content
> - 2.3 accurate metadata, screenshots, functionality claims
> - 2.5.1 public APIs only; 2.5.2 no downloadable code / JS eval
> - 3.1.1 in-app purchase for digital goods; 3.1.2 subscriptions;
>   3.1.3 reader/multiplatform exceptions
> - 4.0 design; 4.2 minimum functionality / "repackaged website"
> - 4.8 Sign in with Apple parity when third-party login is used
> - 5.1.1 privacy policy, permission strings, data collection disclosure
> - 5.1.2 data sharing; 5.1.5 kids; 5.2.1 IP / redistribution;
>   5.3 gaming/contests; 5.6 developer code of conduct
> - Privacy manifest (`PrivacyInfo.xcprivacy`) — declared API-access
>   reasons must match actual code usage; tracking domains declared;
>   data-collection types complete.
>
> **Part B — App Store Connect readiness.** Audit the repo for:
> - Bundle ID, marketing version, build number — unique, bumped.
> - `ITSAppUsesNonExemptEncryption` present and correct for the crypto
>   actually used (standard TLS and on-device AES typically exempt;
>   custom crypto or VPN/proxy behavior typically not).
> - Every `NS*UsageDescription` string present for every entitlement /
>   framework actually used, and user-meaningful (not "we need this").
> - Every entitlement in `*.entitlements` justified by real code.
> - `PrivacyInfo.xcprivacy` reasons match actual API calls (UserDefaults,
>   FileTimestamp, DiskSpace, SystemBootTime, ActiveKeyboards).
> - Asset catalog: `AppIcon` complete at every size; no placeholder art.
> - Launch screen present; supported orientations consistent across
>   phone / pad.
> - No DEBUG-only code, seed data, feature flags, or test credentials
>   shipping in Release.
> - Crash risks on reviewer's first run: `fatalError`, force-unwraps on
>   user input, `try!` on disk/network I/O, uninitialized state on cold
>   launch with no seed data.
> - Third-party SDKs: licenses compatible with redistribution; SDK
>   privacy manifests included; no banned SDKs.
>
> **Part C — submission checklist.** Produce a prioritized, ordered,
> ship-today list in exactly three sections, each a flat bullet list, no
> prose:
>
> 1. **Fixes to ship** — code/config changes, highest-severity first.
> 2. **Assets to produce** — app icon, screenshots per required device
>    class, optional preview video, description, keywords, promotional
>    text, support URL, marketing URL, privacy policy URL.
> 3. **ASC fields to answer** — age-rating questionnaire answers, App
>    Privacy nutrition-label selections, export compliance answer,
>    content rights, advertising identifier declaration, Sign-in
>    reviewer credentials (if any), category + subcategory, price tier.
>
> At the end, draft the **App Review Information → Notes** text to paste
> into App Store Connect: what the app does in one sentence, why each
> permission prompt is requested, any demo credentials, and any
> guideline-interpretation argument the reviewer needs (e.g.
> dev-tool carve-out, reader-app exception, BYOK architecture).

Re-run after every material change. Don't move past Part A while anything
HARD remains open.

---

## 2. The speed-run guide — getting any app through review fast

**Target timeline: 3–7 business days from code-freeze to Ready-for-Sale**
for a typical app. Median first-review time is ~24 h; clean submissions
usually clear in one pass. Complex submissions (code-execution, crypto,
health, kids, finance, IAP) plan on 2–3 passes.

### Phase 0 — Freeze the code

- [ ] Tag a release commit. Everything after is metadata/assets.
- [ ] Bump `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`. Duplicate
      build numbers are an instant bounce.
- [ ] Run the full test suite against the canonical destination. Any
      regression blocks submission.
- [ ] Release-build on a **real device**, not just the simulator. Reviewers
      run on hardware; simulators miss permission-prompt timing, Metal
      bugs, Keychain behavior, and background-mode edge cases.
- [ ] Audit `#if DEBUG` — no seed data, developer menus, feature flags,
      test credentials, or verbose logging in Release.
- [ ] Strip `print`/`NSLog` spam from hot paths; reviewers see console.
- [ ] Cold-launch with a wiped container and walk every feature end-to-end.
      Apps die fastest on a zero-state first launch.

### Phase 1 — Run the audit prompt

- [ ] Paste the prompt from section 1. Work Part C's "Fixes to ship"
      list top-to-bottom.
- [ ] Re-run the prompt after each batch of fixes. Do not submit while
      any HARD finding is unresolved.

### Phase 2 — Produce assets

- [ ] **App icon** — every size the asset catalog asks for; no alpha;
      no rounded-corner pre-masking; matches marketing icon.
- [ ] **Screenshots** — required sizes as of 2026: 6.9" iPhone and 13"
      iPad for universal apps. 3–10 per device class; 3–5 is typical.
      Show the app doing the thing, not marketing chrome. Pick one mode
      (light or dark) and stay consistent across the set.
- [ ] **App Preview video** (optional) — 15–30 s, captured on device with
      `xcrun simctl io … recordVideo` or QuickTime. Skip for v1 unless
      the app has a motion story the screenshots can't tell.
- [ ] **Description** (≤4000 chars) — lead with the one-sentence pitch,
      then a feature bullet list. Don't name competitors. Don't make
      claims the app can't back up ("unlimited," "world's fastest,"
      "fully offline" if you make any network call).
- [ ] **Keywords** (100 chars, comma-separated, no spaces after commas).
      Don't repeat your app name or category — Apple indexes those for
      free. Don't use trademarks you don't own.
- [ ] **Promotional text** (170 chars) — editable post-approval without a
      new build. Use it for launch offers, what's-new teases, etc.
- [ ] **Support URL** — real page, real contact method (email at minimum).
      A GitHub Pages or Notion page works.
- [ ] **Marketing URL** (optional) — the app's landing page if any.
- [ ] **Privacy policy URL** (required) — a page describing exactly what
      data the app collects, transmits, stores, and shares, matching the
      nutrition-label answers in ASC. Mismatches here are the #1 reason
      simple apps get rejected.

### Phase 3 — App Store Connect fields

- [ ] **Age rating** — answer the questionnaire honestly. Unlocked
      web views, UGC, chat, and user-generated images each bump the
      rating. AI-generated content: assume 17+ unless you have strong
      content filters.
- [ ] **App Privacy nutrition labels** — for every data type the app
      touches, select: collected? linked to user? used to track? The
      labels must match the privacy policy and the code. "Data Not
      Collected" is the fastest review signal if true.
- [ ] **Export compliance** — answer `ITSAppUsesNonExemptEncryption`
      correctly. TLS via URLSession and AES via CryptoKit for local
      storage are exempt (Category 5, Part 2, Note 4). Custom crypto,
      VPN, or proxy behavior requires an ERN. France may require an
      additional declaration.
- [ ] **Content rights** — declare any third-party content you use and
      confirm you have rights.
- [ ] **Advertising identifier (IDFA)** — yes only if you actually call
      `ATTrackingManager`. If yes, you also need the ATT prompt and
      corresponding `NSUserTrackingUsageDescription`.
- [ ] **Sign-in required for reviewer** — if the app gates content
      behind login, provide working demo credentials. Missing or broken
      demo creds is the #1 reason account-based apps get rejected.
- [ ] **Categories** — primary determines discoverability; secondary is
      a tiebreaker. Can change post-launch.
- [ ] **Pricing & availability** — pick tier, availability date, and
      territories. "Manual release" lets you control launch time.

### Phase 4 — TestFlight

- [ ] Archive on the Release configuration. **Validate** the archive
      locally before uploading — catches most codesign, provisioning,
      and missing-usage-string issues.
- [ ] Upload; wait ~15–30 min for processing.
- [ ] Install on **a real iPhone and a real iPad** via TestFlight.
      Walk every user-visible feature. Pay attention to: permission
      prompts firing at reasonable moments, cold launch from a wiped
      device, backgrounding and resuming, low-power mode, poor network.
- [ ] Add at least one external tester for 24 h. External TestFlight has
      its own lightweight review; passing it is a strong signal the real
      App Store review will pass too.

### Phase 5 — Submit

- [ ] In the version's **App Review Information → Notes** field, paste
      the reviewer notes drafted by the prompt. Typical content: one
      sentence on what the app does, a bullet per permission prompt
      explaining why it's requested, demo credentials if applicable, and
      any guideline-interpretation argument the reviewer needs.
- [ ] Provide a contact name, phone, and email the reviewer can reach.
- [ ] Attach any demo video or PDF that helps (e.g. for kids apps, a
      "how a 5-year-old would use this" walkthrough).
- [ ] Submit for review. Typical turnaround 12–48 h; complex apps 2–5 d.

### Phase 6 — Handle the first reply

Most likely outcomes, descending probability:

1. **Approved.** Ship.
2. **Metadata reject** — almost always screenshot or description copy.
   Edit text in ASC, resubmit metadata-only (no new build). ~1 h round trip.
3. **Binary reject with a question in Resolution Center** — reply fast;
   Apple often re-reviews same day. Keep the tone factual; cite the
   guideline you're complying with and point to evidence.
4. **Hard reject** — re-run the audit prompt with the rejection message
   pasted in. The new Part C list is your path to resubmission.
5. **Appeal** — for disagreements about guideline interpretation, the
   App Review Board is slower but reasonable. Use sparingly.

### Phase 7 — Release

- [ ] Use **Manually release this version** so you control the launch
      moment (coordinate with marketing, server scaling, press).
- [ ] On release day, flip to "Release this version" and monitor the
      Xcode Organizer crash dashboard for the first 48 h.
- [ ] Prepare a hot-fix branch in case a device/locale-specific crash
      shows up at scale.

---

## 3. Pre-submission gotchas — things that cost a pass

- **Duplicate build number** — bump `CURRENT_PROJECT_VERSION` on every
  upload, even TestFlight re-uploads.
- **Missing usage-description strings** — every entitlement and every
  framework that prompts the user needs one, and it must be human-readable.
- **Privacy manifest mismatch** — declared API reasons must match actual
  calls. Apple's static analyzer checks this at upload time.
- **Placeholder content** — "Lorem ipsum," dummy images, stub buttons
  that open nothing, "Coming soon" sections are instant rejects under 2.1.
- **Login required but no demo creds** — account-based apps are rejected
  the moment the reviewer hits a login wall they can't pass.
- **IAP not wired for digital goods** — selling anything consumed inside
  the app outside IAP is a hard 3.1.1.
- **Trademarks in screenshots/description** — "Works with ChatGPT,"
  "Better than Notion," etc. Either get written permission or scrub.
- **Version bumps without screenshot updates** — if your UI changed, the
  screenshots must change too. 2.3.3 specifically.
- **Third-party SDK privacy manifests** — as of 2024, required SDKs on
  Apple's list must include their own `PrivacyInfo.xcprivacy`. Missing
  one fails the upload.
- **Analytics + "Data Not Collected" nutrition label** — contradictory.
  Pick one and make the code match.

## 4. What to re-check before every resubmission

- Version string bumped (marketing + build).
- Screenshots still match the current UI.
- Any new `NSUsageDescription` strings? — cover them in reviewer notes.
- Any new feature that touches network, accounts, IAP, or user-generated
  content? — re-run the full audit prompt, not an incremental pass.
- Any third-party SDK added? — check its license, privacy manifest, and
  export-compliance implications.
