# App Monitor

App Monitor is a local-first macOS utility for understanding application usage, storage, cleanup opportunities, update status, and uninstall impact from one native SwiftUI dashboard.

The app is built as a Swift Package executable with a lightweight SQLite-backed core. It runs as a standard macOS app with an optional menu bar presence.

## Features

- App inventory across common macOS application locations, with optional broader bundle discovery.
- Foreground app usage tracking with idle/session pause handling.
- Usage analytics for totals, daily trends, top apps, heatmaps, and timeline sessions.
- Spotlight usage import for historical last-used dates, use counts, and used days.
- Storage scans for app bundles and related Application Support, cache, container, preference, log, WebKit, cookie, and diagnostic paths.
- Cleanup suggestions with review, quarantine, restore, and action history flows.
- Large-file review and warning surfaces.
- App health checks for code signing, Gatekeeper, stale bundles, crashes, and permission-sensitive paths.
- Update checks for Mac App Store apps, Homebrew casks/formulae, Apple software updates, and direct-download apps with Sparkle feeds.
- Guided uninstall planning that moves selected app and support files to Trash.
- CSV exports for app tables, daily usage, timeline sessions, summaries, trend buckets, top apps, and heatmaps.

## Requirements

- macOS 14 or newer.
- Xcode command line tools or Xcode with Swift 5.9 support.
- Optional: Homebrew and `mas` for Homebrew and Mac App Store update checks.

## Build And Run

Run the test suite:

```bash
swift test
```

Build a runnable `.app` bundle:

```bash
./scripts/build_app.sh debug
```

Open the packaged app:

```bash
open "build/App Monitor.app"
```

Run the full local check used by this repo:

```bash
./scripts/ci
```

You can also run the Swift package executable directly during development:

```bash
swift run AppMonitor
```

Some macOS app behaviors, including bundle identity, icon resources, menu bar behavior, login item behavior, and permission prompts, are best exercised through the packaged app from `scripts/build_app.sh`.

## Privacy

App Monitor is designed to run locally. It records app inventory, usage, storage scan, cleanup, uninstall, update, and settings data in a local SQLite database under `~/Library/Application Support/App Monitor/`.

It does not include telemetry, accounts, or a hosted backend. Optional update checks may contact third-party update sources or run local update tools such as Homebrew, `mas`, Apple `softwareupdate`, or app-provided Sparkle feeds. See [PRIVACY.md](PRIVACY.md) for details.

## Safety Notes

App Monitor can inspect local app-related storage and can move selected files to quarantine or Trash. Review cleanup and uninstall plans before applying them, especially for containers, preferences, Application Support data, and group containers that may contain user data.

Update installs may require administrator authorization or third-party package manager behavior outside this project.

## Project Structure

- `Sources/AppMonitor`: SwiftUI app, dashboard, menu bar UI, and app lifecycle wiring.
- `Sources/AppMonitorCore`: inventory, usage tracking, storage scanning, cleanup, update, uninstall, analytics, export, and SQLite logic.
- `Tests/AppMonitorCoreTests`: focused core behavior tests.
- `scripts/build_app.sh`: builds and signs a local `.app` bundle.
- `scripts/ci`: runs tests and verifies app bundle creation.

## License

App Monitor is released under the MIT License. See [LICENSE](LICENSE).
