# ProfileSwitcher

macOS menu bar utility for switching between ChatGPT (cloud) and Splash (local) profiles in the Codex/ChatGPT desktop app.

## Why

The ChatGPT desktop app uses `~/.codex/config.toml` for configuration. Cloud (OpenAI) and local (Splash) models **cannot coexist** in the same config — they conflict. This app lets you switch profiles with one click from the menu bar.

## Features

- 🖥️ Lives in the menu bar (no dock icon)
- 🔀 One-click profile switching (ChatGPT ↔ Splash)
- ⚙️ Settings window to manage/add/delete custom profiles
- 💾 Automatic backup of `config.toml` before each switch
- 🔄 Quits & relaunches ChatGPT with the selected profile

## Requirements

- macOS 14.0+ (Apple Silicon)
- [Splash](https://github.com/unsloth/splash) (for local models)
- ChatGPT/Codex desktop app

## Build

```bash
./build.sh
```

This compiles with `swiftc` and produces `build/ProfileSwitcher.app`.

### Install

```bash
cp -R build/ProfileSwitcher.app /Applications/
```

## Usage

1. Launch **ProfileSwitcher** (menu bar icon: `⇄ C` or `⇄ S`)
2. Select a profile from the dropdown menu
3. Confirm the switch — ChatGPT will restart with the new profile

### Profiles

Profiles are stored in:
```
~/Library/Application Support/ProfileSwitcher/profiles.json
```

You can edit profiles via the built-in Settings window.

### Config Backup

Before each switch, the current `config.toml` is backed up to:
```
~/.codex/config.toml.bak-profileswitcher
```

## Project Structure

```
├── Sources/
│   ├── main.swift                    # Entry point
│   ├── AppDelegate.swift             # Menu bar + actions
│   ├── ProfileManager.swift          # Core logic (config modification, app management)
│   └── SettingsWindowController.swift # Settings UI (AppKit)
├── Info.plist                        # LSUIElement (no dock icon)
├── build.sh                          # Build script (swiftc → .app bundle)
└── README.md
```

## How It Works

Switching a profile:
1. Backs up `~/.codex/config.toml`
2. Removes model-related lines (`model`, `model_provider`, `model_catalog_json`, etc.)
3. Removes `[model_providers.splash]` section (if present)
4. Inserts the new profile's settings at the top of the file
5. Appends provider sections (e.g. `[model_providers.splash]`) at the end
6. Quits ChatGPT → waits → relaunches

## License

MIT
