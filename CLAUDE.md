# CLAUDE.md — Concrete Crown

## Source of truth

docs/CONCRETE_CROWN_SPEC.md. Build order: §16. When the spec is silent: §0.1.

## Environment

- Godot binary: $GODOT (path + version recorded in docs/DECISIONS.md).
- Godot 4.x standard build, GDScript only. No C#/.NET.
- Run tools/verify.sh (or tools/verify.ps1) after every meaningful change.

## Hard rules

1. Static typing everywhere: typed vars, params, and returns.
2. Content lives in /data JSON and is read through DataDB. Tuning numbers live in data/tuning, not in gameplay code.
3. Every system gets unit tests. Every scene gets a smoke test.
4. Never report a check as passed without running it in this session.
5. Never block. Decide, log in docs/DECISIONS.md, stub with `# TODO(spec §x):`, continue.
6. Only procedural or CC0 assets (log CC0 in CREDITS.md). No trademarks, real brands, real people, or song samples.
7. Commit each passing sub-step ("M3.2: parry windows"). Milestone commit + tag only at milestone end, after VERIFY: ALL GREEN.
8. Update docs/PROGRESS.md at every milestone: status, what shipped, known issues, deferrals.
9. Files under ~400 lines, one class per file, cross-system events through EventBus.
10. Headless can't render. When a display exists, run the render smoke and Read a few screenshots in shots/ at M1, M6, M8, M12.
11. Don't weaken or delete tests to make them pass unless the spec changed. Fix the code.
12. Respect the performance budgets in §15.17 (MultiMesh for repeated props, light budget).

## Commands

- Verify: tools/verify.sh [--full]
- Tests: $GODOT --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit
- One smoke scene: $GODOT --headless --path . res://tests/smoke/<name>.tscn --quit-after 900
- QA script: $GODOT --headless --path . -- --qa-run=<script_id>

## Style

snake_case files, PascalCase class_name, past-tense signals (bucket_scored), frame data in frames at 60 fps.

## Local notes (this machine)

- Windows: run `powershell -ExecutionPolicy Bypass -File tools/verify.ps1 [--full]`.
- `$GODOT` falls back to `tools/.godot_path` (gitignored) when the env var is unset.
- Smoke scenes must print `SMOKE OK <name>`; QA scripts live in `tests/qa/qa_<id>.gd`.
- Simulation code is pure (RefCounted, no scene tree) so it runs headless and frame-exact; Node3D views only render it.
