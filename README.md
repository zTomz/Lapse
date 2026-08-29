# Lapse

Lapse is a compact Windows companion that automatically measures active PC time and keeps a tiny, session-specific todo list visible. It starts tracking without a Start button, pauses for idle/locked/sleep states, and can collapse into a 244 × 52 timer strip.

> Flutter's Desktop Windowing API is experimental and not production-stable. This project intentionally targets Flutter's `main` channel and can require updates after any SDK upgrade.

## Features

- Correct active-time accumulation from monotonic intervals rather than timer ticks
- Windows-wide idle detection with a five-minute threshold
- Lock/unlock and suspend/resume handling
- Compact always-on-top, frameless overlay with saved multi-monitor-safe position
- Expanded and collapsed window modes
- Manual pause/resume with a persisted `PAUSED` session state
- Session tasks: add, complete, edit, delete, keyboard submit/cancel, and progress
- Atomic local JSON persistence in `%LOCALAPPDATA%\Lapse\state.json`
- Same-boot session recovery and fresh tasks after a new boot
- Current-user Windows autostart without administrator rights
- Tray menu for opening, collapsing/expanding, autostart, topmost, and deliberate quit
- Close-to-tray behavior so tracking continues in the background
- A resizable native Dashboard with overview, 7-day chart, applications, sessions, and settings
- Local-only Windows foreground-application usage during ACTIVE intervals
- Versioned session history and backward-compatible schema migration

## Screenshot

_Screenshot placeholder — capture the overlay from a local Windows run._

## Requirements and setup

- Windows 10 or newer
- Visual Studio with the Desktop development with C++ workload
- Flutter `main` channel with experimental windowing enabled

```powershell
flutter channel main
flutter upgrade
flutter config --enable-windowing
flutter pub get
dart run build_runner build
flutter run -d windows
```

The installed SDK used for this version was Flutter `3.48.0-1.0.pre-515` / Dart `3.14.0-179.0.dev` from 29 August 2026.

## Architecture

`runWidget()` mounts a Riverpod `ProviderScope` above Flutter's experimental `WindowManager`. The overlay and dynamically registered Dashboard each use their own `WindowController` while sharing one `SessionController`, interval accumulators, tasks, analytics, preferences, and persistence layer in the same widget tree.

The Dart services isolate platform and persistence concerns:

- `ActivityDetector` exposes activity states without leaking Win32 details.
- `ForegroundAppTracker` polls the foreground process once per second and emits only changes.
- `WindowsPlatformService` is the only Dart platform-channel boundary.
- `JsonPersistenceService` owns versioned, fault-tolerant local state.

The small Windows runner bridge exists because the experimental Flutter API does not currently expose window position, frameless/topmost/taskbar behavior, system tray, global last-input time, foreground-process metadata, session/power notifications, or per-user autostart. App/session/task and analytics logic remains in Dart.

## Experimental Windowing API

The app uses these current SDK symbols:

- `runWidget()` instead of `runApp()`
- internal `package:flutter/src/widgets/_window.dart`
- `WindowController`, `WindowControllerDelegate`, and `Window`
- `WindowManager`, `WindowRegistry`, and `WindowEntry` for the Dashboard window
- `WindowController.setSize()` for expanded/collapsed resizing

The two narrow analyzer suppressions around the internal import are required until Flutter publishes this API. They are not global analyzer exclusions.

## Development

```powershell
dart format .
dart run build_runner build
flutter analyze
flutter test
flutter build windows
```

Do not edit `*.g.dart` files manually. Regenerate them after changing Riverpod annotations.

## Known limitations

- The Windowing API can break between Flutter `main` revisions.
- Native styling locates the overlay and Dashboard by their centrally defined titles; explicit native handles can replace this when Flutter exposes them.
- Boot identity uses a rounded Windows boot-time heuristic derived from `GetTickCount64`; a large system-clock correction can conservatively start a fresh session.
- Tracking checkpoints every 30 seconds and on meaningful changes. An abrupt process kill can lose at most the current uncheckpointed interval; normal close-to-tray and Quit persist first.
- Lapse is Windows-only and intentionally has no cloud sync, URL, document-title, or keystroke tracking.
