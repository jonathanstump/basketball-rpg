#!/usr/bin/env bash
# Export Concrete Crown for Windows and Linux into builds/ (spec §16 M14).
# Usage: tools/export.sh [--dry-run]   (needs the Godot export templates)
set -u
cd "$(dirname "$0")/.."
GODOT="${GODOT:-$(cat tools/.godot_path 2>/dev/null)}"
OUT="builds"
[ "${1:-}" = "--dry-run" ] && OUT="builds/dryrun"
failed=0
export_one() {
	mkdir -p "$(dirname "$2")"
	if "$GODOT" --headless --path . --export-release "$1" "$2" && [ -f "$2" ]; then
		echo "EXPORT OK $1 -> $2"
	else
		echo "EXPORT FAIL $1"
		failed=$((failed + 1))
	fi
}
export_one "Windows Desktop" "$OUT/windows/ConcreteCrown.exe"
export_one "Linux" "$OUT/linux/ConcreteCrown.x86_64"
exit $failed
