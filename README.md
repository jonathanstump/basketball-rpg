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
