# Tidy

A macOS cleaner focused on two things: finding junk files and uninstalling apps together with everything they leave behind.

## Features

- **Junk** — user and container caches, Chromium/Electron caches, logs, Xcode junk, Trash, broken preferences and broken launch agents.
- **Uninstaller** — removes an app plus its container, group containers, preferences, Application Support, caches, logs, crash reports, saved state, web data, launch agents and daemons, and privileged helpers. Filter apps by last use, store or vendor, and tick several apps to uninstall them together.
- **Leftovers** — files named after bundle identifiers that no installed app uses. Nothing is selected by default.

Everything goes to the Trash (items already in the Trash are deleted). A dry-run switch simulates a cleanup without touching anything. Files owned by the system, such as App Store apps or items in `/Library`, are moved to the Trash after you approve with your administrator password.

## Requirements

- macOS 13 or later
- Xcode 15 or later

## Running

```sh
open Package.swift
```

Select the `Tidy` scheme and run it on **My Mac**. From the terminal:

```sh
swift build
swift run Tidy
swift test
```

Tidy needs **Full Disk Access** to see app containers and the Trash. While developing, grant it to Xcode or Terminal in System Settings → Privacy & Security → Full Disk Access.

## Building the app

```sh
bash scripts/build-app.sh            # builds build/Tidy.app
bash scripts/build-app.sh --install  # builds and copies it to /Applications
```

The app is signed for local use only. Each rebuild changes its signature, so turn Tidy off and on again in Full Disk Access after installing a new build.

## Layout

| Path | Contents |
| --- | --- |
| `Sources/TidyCore/JunkScanning` | Scanners, scan service and scanner factory |
| `Sources/TidyCore/Uninstalling` | App catalog, residue matchers and fetchers, uninstall coordinator, leftover finder |
| `Sources/TidyCore/Removal` | Removers, removal policies and the ignore list |
| `Sources/TidyCore/Resources/rules.json` | Path rules for the junk scanner |
| `Support` | App bundle `Info.plist` and icon |
| `scripts/build-app.sh` | Builds `Tidy.app` |
| `Sources/Tidy` | SwiftUI app |
| `Tests/TidyCoreTests` | Unit tests |

## Adding a junk location

Most locations only need a new entry in `rules.json`:

```json
{
  "id": "example-cache",
  "category": "userCaches",
  "path": "~/Library/Application Support/Example/Cache",
  "scope": "itself",
  "selectedByDefault": true
}
```

`scope` is `children` to list every item inside the folder, or `itself` to treat the folder as one item. A `*` path component matches any folder.
