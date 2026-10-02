# Concrete Crown

> One ball. Five boroughs. No fouls.

A 3D souls-like action RPG where every attack, parry and finisher is a basketball move. Built in Godot 4 with GDScript; all art and audio are procedural.

- Design spec: [docs/CONCRETE_CROWN_SPEC.md](docs/CONCRETE_CROWN_SPEC.md)
- Progress: [docs/PROGRESS.md](docs/PROGRESS.md) · Decisions: [docs/DECISIONS.md](docs/DECISIONS.md)

## Requirements

- Godot 4.7 standard (not .NET). Set `GODOT` to the binary path (or put it in `tools/.godot_path`).
- Git + Git LFS.

## Verify

```
tools/verify.sh [--full]                                        # macOS/Linux/Git Bash
powershell -ExecutionPolicy Bypass -File tools/verify.ps1 [--full]  # Windows
```

The last line is `VERIFY: ALL GREEN` (exit 0) or `VERIFY: FAILED (<n> problems)`.

## Play

Open the project in the Godot 4.7 editor and press **F5**, or run it from a terminal:

```
"$GODOT" --path .
```

Controls are listed in Settings → Controls, where every action can be remapped. Gamepads are supported, with prompts that follow the last-used device. Steam Deck picks the Deck quality preset on first boot.

## Build (export)

1. Install the export templates for the running Godot version once: open the editor, go to **Editor → Manage Export Templates → Download and Install**, or unpack the official `.tpz` into `%APPDATA%\Godot\export_templates\<version>` (Windows) or `~/.local/share/godot/export_templates/<version>` (Linux).
2. Export both presets (Windows Desktop and Linux, from `export_presets.cfg`) into `builds/`:

```
tools/export.sh [--dry-run]                                          # macOS/Linux/Git Bash
powershell -ExecutionPolicy Bypass -File tools/export.ps1 [-DryRun]  # Windows
```

Each target prints `EXPORT OK <preset> -> <path>`. A dry run writes to `builds/dryrun/`.

## Steam

`SteamService` uses the GodotSteam GDExtension when it is present: achievements (Appendix B, rules in `core/stats/achievement_rules.gd`) and rich presence. Without it, everything still runs; unlocks are mirrored to `user://achievements.json`. To ship on Steam, install GodotSteam into `addons/` and set the app ID.

## Useful commands

```
"$GODOT" --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit   # unit tests
"$GODOT" --headless --path . -- --qa-run=balance      # boss-sim balancing pass -> docs/BALANCE.md
"$GODOT" --path . -s res://tools/screenshot.gd        # render smoke + RENDER STATS (needs a display)
```

## License

Third-party licenses are in `licenses/`, and attributions are in [CREDITS.md](CREDITS.md). All game art, music and sound are generated procedurally by the code in this repository.
