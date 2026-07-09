# Privacy Policy

Effective date: July 9, 2026

App Monitor is an open-source, local-first macOS utility. This policy describes the behavior of this repository's app as provided here. Forks, repackaged builds, or distributed variants should publish their own policy if their behavior changes.

## Summary

App Monitor does not include user accounts, telemetry, advertising SDKs, analytics SDKs, or a hosted backend. The app is intended to store its working data on your Mac.

## Data The App Stores Locally

Depending on which features you use, App Monitor may store:

- Installed app names, bundle identifiers, versions, paths, install dates, and last-seen timestamps.
- Foreground app usage sessions, including app name, bundle identifier, app path, start time, end time, and duration.
- Imported Spotlight metadata such as last-used dates, use counts, and used days.
- Storage scan results for app bundles and related macOS folders, including file paths, categories, sizes, warnings, and scan timestamps.
- Cleanup suggestions, quarantine paths, restore history, large-file review state, tags, ignored apps, and app health findings.
- Uninstall plans/results and update check/install results.
- App settings such as reporting period, scan schedule, update preferences, and launch-at-login preference.

The primary local database is created at:

```text
~/Library/Application Support/App Monitor/AppMonitor.sqlite
```

macOS may also store related app preferences in standard user defaults locations.

## Network Activity

App Monitor does not send its local usage database to the project author or to an App Monitor server.

Optional update features can cause network activity through local tools or app-provided update feeds:

- Homebrew checks can run `brew update` and `brew outdated`.
- Mac App Store checks can run `mas outdated`.
- Apple software checks can run `softwareupdate`.
- Direct-download update detection can request Sparkle appcast URLs declared by installed apps.

Those services, package managers, and update feeds are controlled by third parties and may have their own privacy practices.

## File System Access

App Monitor scans standard application and user Library locations to estimate app-related storage. Cleanup and uninstall features can move selected files to quarantine or Trash after user action. Some files may contain personal data from other apps, so review selected items before applying cleanup or uninstall actions.

## Exports

CSV exports are saved only when you choose to export data and select a destination. Exported files are outside App Monitor's database and remain wherever you save them.

## Deleting Local Data

To remove App Monitor's local database, delete:

```text
~/Library/Application Support/App Monitor/
```

Also remove any CSV exports you created and remove the app from Login Items if you enabled launch at login.

## Security

Update installs, Mac App Store actions, Apple software updates, and some file operations may request administrator authorization through macOS. App Monitor does not need or store your administrator password.

## Contact

For issues with this open-source project, use the GitHub repository issue tracker.
