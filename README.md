# Lapse

Lapse is a compact Windows companion that automatically measures active PC time and keeps a tiny, session-specific todo list visible. It starts tracking without a Start button, pauses for idle/locked/sleep states, and can collapse into a 228 × 52 timer strip.

> Flutter's Desktop Windowing API is experimental and not production-stable. This project intentionally targets Flutter's `main` channel and can require updates after any SDK upgrade.

## Features

- Correct active-time accumulation from monotonic intervals rather than timer ticks
- Windows-wide idle detection with a five-minute threshold
- Lock/unlock and suspend/resume handling
- Compact always-on-top, frameless overlay with saved multi-monitor-safe position
- Expanded and collapsed window modes
- Session tasks: add, complete, edit, delete, keyboard submit/cancel, and progress
- Atomic local JSON persistence in `%LOCALAPPDATA%\Lapse\state.json`
- Same-boot session recovery and fresh tasks after a new boot
- Current-user Windows autostart without administrator rights
- Tray menu for opening, collapsing/expanding, autostart, topmost, and deliberate quit
- Close-to-tray behavior so tracking continues in the background

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

`runWidget()` mounts a Riverpod `ProviderScope` above a native `Window` created by `WindowController`. A single `SessionController` owns the current session, activity accumulator, tasks, overlay preferences, and persistence coordination. This shared root is ready for a future dashboard window in the same widget tree.

The Dart services isolate platform and persistence concerns:

- `ActivityDetector` exposes activity states without leaking Win32 details.
- `WindowsPlatformService` is the only Dart platform-channel boundary.
- `JsonPersistenceService` owns versioned, fault-tolerant local state.

The small Windows runner bridge exists because the experimental Flutter API does not currently expose window position, frameless/topmost/taskbar behavior, system tray, global last-input time, session/power notifications, or per-user autostart. App/session/task logic remains in Dart.

## Experimental Windowing API

The app uses these current SDK symbols:

- `runWidget()` instead of `runApp()`
- internal `package:flutter/src/widgets/_window.dart`
- `WindowController`, `WindowControllerDelegate`, and `Window`
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
- Native styling locates the single v1 overlay by its centrally defined title; future additional regular windows should receive explicit native handles when Flutter exposes them.
- Boot identity uses a rounded Windows boot-time heuristic derived from `GetTickCount64`; a large system-clock correction can conservatively start a fresh session.
- Tracking checkpoints every 30 seconds and on meaningful changes. An abrupt process kill can lose at most the current uncheckpointed interval; normal close-to-tray and Quit persist first.
- v1 is Windows-only and has no cloud sync or per-application analytics.
