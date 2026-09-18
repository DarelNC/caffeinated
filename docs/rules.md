# Project rules

Adapted from the workspace-level `frag-ment/rules/` library. Caffeinated is a
single-purpose, offline, Android-only utility (keep the screen on, optionally
for a fixed duration) — most of the reusable library assumes a networked
product with a backend, so a lot of it doesn't apply here. What follows is
what was kept, dropped, or reshaped, and why.

## Dropped entirely

- **architecture.md** — the whole file is about not calling third-party APIs
  directly from a client and designing for upstream failover. Caffeinated has
  no backend, no third-party API, no network calls at all: it's a Flutter UI
  talking to a native Android foreground service over a MethodChannel. None
  of it applies.
- **stack.md's "match framework to deployment shape"** — there's one
  deployable (the Android app itself), not a frontend/backend split.
- **stack.md's caching/storage rule** — there's no request path or shared
  store; the only state is "is the service running" and "which timer is
  selected," held in memory / the Android service itself.

## Kept, as-is

- **stack.md — License: MIT unless there's a specific reason otherwise.**
- **stack.md — Default branch for new repos is `master`.** (already true here)
- **product.md — Do a real naming pass before anything goes public.** "Caffeinated"
  is a working name; before a Play Store listing or any public release, check
  for an existing app/trademark collision.
- **product.md — Weigh accounts/login/PII as a real decision, not a default.**
  Trivially satisfied today: no accounts, no login, no PII collected. Keeping
  this written down so a future feature (e.g. a widget, cloud sync) doesn't
  quietly grow an account system without that being an explicit call.
- **process.md — tiered documentation/review discipline.** Fast lane for
  typo/copy/small-bug-fix changes; decision lane (write it down + one honest
  adversarial pass) for real calls — e.g. dropping non-Android platforms,
  removing the wakelock_plus dependency in favor of a native foreground
  service, or the timer/notification design. Publish gate: doc-sync before
  anything goes public (already the practice — this file exists because of
  it).
- **process.md — the adversarial pass is real scrutiny, not performance.**
  Applies especially to anything touching the wake-lock/foreground-service
  code: this app's entire reason to exist is "the screen actually stays on
  when you background it," so a change here that looks right but doesn't
  hold up under Android's foreground-service/Doze restrictions is worse than
  a change anywhere else in the app.
- **process.md — scope discipline / cut list.** A feature idea (e.g. a home
  screen widget, more timer presets) gets its own entry here when it's
  actually decided, not silently built because a competitor has it.

## Kept, adapted

- **design.md — full "don't ship anything that looks AI-generated" constraint.**
  The banned-pattern list is written for web landing pages; the Android
  equivalents that count as the same failure are:
  - Default Material `ElevatedButton` on a plain white `Scaffold` with no
    typographic or color identity (this is what the app looked like before
    this pass).
  - Default `Icons.*` from the Material icon set instead of the app's own
    bundled coffee-cup artwork (`assets/images/ic_caffeinated_*.svg`, which
    existed in the repo but weren't wired into the UI at all).
  - A static screen with no motion tied to state — "screen is keeping your
    device awake" is a live, ongoing state and the UI should read as alive,
    not as a form that was submitted.
  The "do instead" list (real typographic hierarchy, a deliberate color
  system, motion with intent, custom iconography) is the direct brief for
  the maximalist redesign.
- **design.md — iterate live, don't commit the exploration.** Applies the
  same way: try palette/motion variations in the running app, keep only the
  winner, note rejected directions here instead of leaving dead widgets in
  git history.

## Cut list (things considered and deliberately not built yet)

- Home-screen widget / quick-settings tile — mentioned as a "maybe later"
  idea; no decision made yet, not started.
- Cross-platform support (iOS/desktop/web) — deliberately dropped. The
  product is "keep an Android phone's screen on while backgrounded," which
  needs a real foreground service + wake lock; that's an Android-specific
  mechanism with no equivalent that behaves the same way on the other
  platforms this Flutter template scaffolded by default. Re-adding a
  platform is a decision-lane change, not a default to restore.
- `wakelock_plus` (the Flutter-side, cross-platform wakelock package) —
  removed as dead code and, more importantly, as the *wrong* mechanism for
  this product: it works by setting `FLAG_KEEP_SCREEN_ON` on the Activity's
  window, which only has an effect while that window is actually in the
  foreground. It cannot keep the screen on once the app is backgrounded,
  which is the entire point of this app — so it was never going to satisfy
  the requirement even wired up correctly.
