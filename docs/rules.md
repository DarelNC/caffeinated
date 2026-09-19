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
  system, motion with intent, custom iconography) was the direct brief for
  the first redesign pass (an improvised neo-brutalist look), later replaced
  by an actual named design system — see below.
- **design.md — iterate live, don't commit the exploration.** Applies the
  same way: try palette/motion variations in the running app, keep only the
  winner, note rejected directions here instead of leaving dead widgets in
  git history.

## Design system: "New Cycle"

The UI now follows an external design system doc ("New Cycle") rather than
an improvised look, superseding the first neo-brutalist redesign pass
mentioned above. It's a general brutalist-functional system (hard borders,
zero corner radius, offset hard shadows, one signal accent color, three
named type faces) meant for any surface, not written for this app or for
Flutter specifically — three adaptation calls were made bringing it in:

- **Ground palette: Oxblood, not the system's default Plum.** The doc
  sanctions three interchangeable dark grounds (Plum/Night/Oxblood) and says
  to pick one and stay in it. Oxblood's deep red-brown reads as
  coffee/espresso-adjacent, which neither Plum (purple) nor Night (blue)
  do — a real fit for what this app is, not just the first option in the
  list.
- **Fonts bundled locally, not fetched from Google Fonts at runtime.** The
  three faces (Archivo Black, Major Mono Display, DM Serif Display italic)
  are Google Fonts; this app is deliberately offline (see the dropped
  architecture.md/stack.md network-dependency rules above), so the actual
  OFL-licensed `.ttf` files are committed under `assets/fonts/` and declared
  in `pubspec.yaml`'s `fonts:` block instead of using a package that fetches
  them over the network on first use.
- **Centering, read narrowly.** The system's hard rule is "everything is
  flush left," with one named exception: "a single-element empty state."
  This app's core screen (icon + Archivo Black headline + one DM Serif
  italic line + one primary action) is structurally identical to the doc's
  own named Empty State component, so that block is centered under the
  exception; the brand mark stays flush left as page chrome, and the
  duration row/button are full-width controls, not centered text, so the
  rule doesn't apply to them either way.

The coffee-mug icons (`assets/images/ic_caffeinated_*_large.svg`) were also
redrawn from scratch to match the system's icon language (straight edges,
uniform stroke, square caps/joins, no fill) — the originals had soft curves
and inconsistent stroke weights that didn't fit.

**Superseded by a concrete mockup.** The above (built from prose alone,
without being able to see the running result — no Android SDK on the build
machine) didn't actually look right. The user then supplied a pixel-precise
mockup built externally, and the UI was rebuilt to match it directly instead
of continuing to interpret the abstract doc. Concrete differences from the
prose-only pass:

- A fourth face, **Space Grotesk**, for body/UI text the abstract doc would
  have put in Major Mono Display — the mockup uses it for labels, the
  footer tagline, and the floating notes. Bundled locally as a variable
  font (`SpaceGrotesk[wght].ttf`), same offline reasoning as the other three.
- The coffee-mug **SVG icons were dropped entirely** in favor of a mug built
  from plain bordered boxes with an animated liquid fill (0–72% height) tied
  to the running state — a more literal, better payoff visual than an
  icon swap, and it directly needed the real countdown data rather than
  reproducing it as a static image. `flutter_svg` was removed as a
  dependency along with the icon files.
- Decorative motion the abstract system only gestures at (ambient loops
  "belong on marketing surfaces") is used directly here: a scrolling
  ticker marquee, two slow-rotating background rings, staggered steam
  wisps, and floating sticky notes. All are transform-only and only run
  while the app is foregrounded and the screen is on, so they don't carry
  the same battery cost as the notification-heartbeat idea that was
  rejected earlier in this doc for running unattended in the background.
- The "time left" panel now shows a real countdown backed by the native
  service's actual end time (`getStatus` returns it), not a value guessed
  or reconstructed client-side — seeded correctly even if the app was
  closed and reopened mid-countdown.

## Android build toolchain versions

Gradle/AGP/Kotlin are pinned in `android/gradle/wrapper/gradle-wrapper.properties`
and `android/settings.gradle`, not resolved automatically — they need bumping
by hand as Flutter's own minimums move. When bumping, match the exact
combination the installed Flutter SDK was built and tested against
(`templateDefaultGradleVersion` / `templateAndroidGradlePluginVersion` /
`templateKotlinGradlePluginVersion` in `flutter_tools/lib/src/android/gradle_utils.dart`,
also reproducible by running `flutter create` in a scratch directory and
reading what it generates) rather than whatever the latest AGP release
happens to be — the two can be well ahead of each other, and the newest AGP
may need a DSL/toolchain jump this Flutter version doesn't support yet.
Current pin (Flutter 3.44.0): Gradle 9.1.0, AGP 9.0.1, Kotlin 2.3.20,
Java/Kotlin target 17, with `android.newDsl=false` / `android.builtInKotlin=false`
in `gradle.properties` — both explicit opt-outs from AGP 9's new default
behavior, matching what Flutter's own template does for this release rather
than migrating ahead of when Flutter itself defaults to them.

`compileSdk`/`targetSdk` are not hardcoded — they reference
`flutter.compileSdkVersion`/`flutter.targetSdkVersion`, which are set by the
installed Flutter SDK itself (currently 36 / Android 16) and move forward
automatically on a Flutter upgrade, with no file to edit here.

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
