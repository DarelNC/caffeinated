# caffeinated

Keeps your Android screen on — even after you switch away from the app or
lock the phone — for a set duration or indefinitely. No account, no data
collection, no network calls.

> **Working name.** "caffeinated" hasn't been through a naming/trademark
> pass yet — see [docs/rules.md](docs/rules.md) for what that means before
> this goes anywhere public.

<!-- TODO(screenshot): idle state -->
<!-- TODO(screenshot): active state, timer running -->
<!-- TODO(screenshot): persistent notification -->

## Why Android only

The core feature — staying on after you leave the app — needs a real
background wake lock. iOS grants no equivalent to third-party apps: once an
app is backgrounded, the OS suspends it within seconds, with no public API
to keep the screen alive from there. That's a hard platform limitation, not
a missing feature, so this app doesn't pretend otherwise by shipping a
foreground-only iOS build that stops working the moment you switch apps.
See `docs/rules.md`'s cut list for the full reasoning.

## How it works

- A native Android foreground service (`KeepScreenOnService`) acquires a
  `PowerManager` wake lock and posts an ongoing, low-priority notification
  while active — required by Android for any app holding the device awake
  in the background.
- Pick a duration (5 / 10 / 30 minutes, or indefinitely) before starting.
  The notification shows a live countdown via Android's native chronometer
  view, and the service schedules its own auto-stop — no need to keep the
  app open for the timer to matter.
- Reopening the app re-syncs with the service's actual state (not a
  locally-remembered guess), since the OS can kill the service in the
  background independently of anything the app does.

## Running it

```bash
flutter pub get
flutter run
```

Requires the Android SDK and a device or emulator. There's no iOS, web,
desktop, or Linux target — see "Why Android only" above.

## Project structure

- `lib/main.dart` — UI and app state.
- `lib/screen_awake_service.dart` — the MethodChannel bridge to native
  Android; the widget tree never talks to platform channels directly.
- `android/app/src/main/kotlin/.../KeepScreenOnService.kt` — the actual
  foreground service: wake lock, notification, auto-stop timer.
- `android/app/src/main/kotlin/.../MainActivity.kt` — the MethodChannel
  handler bridging Dart calls to the service.
- `docs/rules.md` — the project's own adapted copy of this workspace's
  rules library (design system, process discipline, what got dropped and
  why). Worth reading before touching UI or architecture.

## Permissions

| Permission | Why |
|---|---|
| `WAKE_LOCK` | Keeps the screen/CPU on while the service is active. |
| `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_SPECIAL_USE` | Required to run a background service that isn't media/location/etc. — "special use" is the correct Android 14+ category for this use case, with a justification declared in the manifest. |
| `POST_NOTIFICATIONS` | Shows the ongoing notification Android requires while the wake lock is held. Without it, the wake lock still works — you just won't see the status notification. |

No other permissions, no analytics, no network access.

## License

[MIT](LICENSE) — the default per this workspace's stack rules, no specific
reason to pick otherwise.
