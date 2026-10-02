#!/usr/bin/env bash
# Concrete Crown verification harness (spec 15.16) for macOS/Linux/Git Bash.
# Usage: tools/verify.sh [--full]
# Godot path: $GODOT, else tools/.godot_path, else `godot` on PATH.
set -u
FULL=0
[ "${1:-}" = "--full" ] && FULL=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1
if [ -z "${GODOT:-}" ] && [ -f tools/.godot_path ]; then GODOT="$(tr -d '\r\n' < tools/.godot_path)"; fi
GODOT="${GODOT:-godot}"
PROBLEMS=0
ERR_RE='^[[:space:]]*(SCRIPT ERROR|USER ERROR|ERROR|SHADER ERROR):'
TMP_OUT="$(mktemp)"
CUR_PID=""
# Never leave Godot running: on exit or interrupt, stop the current child
# (timeout forwards TERM to Godot; on Windows the console wrapper takes the
# real Godot down with it).
cleanup() { [ -n "$CUR_PID" ] && kill "$CUR_PID" 2>/dev/null; rm -f "$TMP_OUT"; }
trap cleanup EXIT
trap 'cleanup; exit 130' INT TERM HUP

run_godot() { # timeout_s args...
	local t="$1"; shift
	timeout "$t" "$GODOT" "$@" > "$TMP_OUT" 2>&1 &
	CUR_PID=$!
	wait "$CUR_PID"
	local code=$?
	CUR_PID=""
	sed -i 's/\x1b\[[0-9;]*m//g' "$TMP_OUT"
	return $code
}
fail() { echo "  FAIL: $1"; PROBLEMS=$((PROBLEMS + 1)); }
show_errors() { grep -E "$ERR_RE" "$TMP_OUT" | head -15 | sed 's/^/    /'; }

echo "== Godot: $GODOT"
VER="$("$GODOT" --version 2>/dev/null | tail -1 | tr -d '\r')"
echo "   version $VER"

echo "== [1/5] Import resources"
if run_godot 900 --headless --path . --import && ! grep -qE "$ERR_RE" "$TMP_OUT"; then echo "  ok"; else fail "import"; show_errors; fi

echo "== [2/5] Data validation + map lint"
run_godot 300 --headless --path . -s res://tools/validate_data.gd; code=$?
grep -E "DATA PROBLEM|VALIDATE DATA" "$TMP_OUT" | sed 's/^/    /'
if [ $code -ne 0 ] || ! grep -qE "VALIDATE DATA: .* 0 problems" "$TMP_OUT"; then fail "data validation"; fi
run_godot 300 --headless --path . -s res://tools/map_lint.gd; code=$?
grep -E "MAP" "$TMP_OUT" | sed 's/^/    /'
if [ $code -ne 0 ] || ! grep -qE "MAP LINT: .* 0 problems" "$TMP_OUT"; then fail "map lint"; fi

echo "== [3/5] Unit + integration tests (GUT)"
run_godot 1800 --headless --path . -s res://addons/gut/gut_cmdln.gd -gdir=res://tests -ginclude_subdirs -gexit; code=$?
grep -E "^(Scripts|Tests|Passing Tests|Failing Tests|Risky|Pending|Asserts|Time)[[:space:]]" "$TMP_OUT" | sed 's/^/    /'
if [ $code -ne 0 ] || ! grep -q "All tests passed" "$TMP_OUT"; then
	fail "GUT tests (exit $code)"; grep -E "\[Failed\]|FAILED|SCRIPT ERROR|Parse Error|ERROR:" "$TMP_OUT" | head -40 | sed 's/^/    /'
elif grep -qE "SCRIPT ERROR|Parse Error" "$TMP_OUT"; then fail "GUT run printed script errors"; show_errors; fi

echo "== [4/5] Smoke scenes"
for f in tests/smoke/*.tscn; do
	name="$(basename "$f" .tscn)"
	run_godot 600 --headless --path . "res://$f" --quit-after 900 --fixed-fps 60
	if grep -qE "$ERR_RE" "$TMP_OUT"; then fail "$name printed errors"; show_errors
	elif ! grep -q "SMOKE OK $name" "$TMP_OUT"; then fail "$name did not report SMOKE OK"; tail -15 "$TMP_OUT" | sed 's/^/    /'
	else echo "  ok  $name"; fi
done

if [ $FULL -eq 1 ]; then
	echo "== [5/5] Full: QA scripts, render smoke, export dry run"
	for f in tests/qa/qa_*.gd; do
		base="$(basename "$f" .gd)"; [ "$base" = "qa_script" ] && continue
		id="${base#qa_}"
		run_godot 1800 --headless --path . --fixed-fps 60 -- "--qa-run=$id"
		if grep -q "QA PASS $id" "$TMP_OUT" && ! grep -qE "$ERR_RE" "$TMP_OUT"; then echo "  ok  QA $id"
		else fail "QA $id"; grep -E "QA (PASS|FAIL)" "$TMP_OUT" | sed 's/^/    /'; show_errors; fi
	done
	if [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ] || [ "${OS:-}" = "Windows_NT" ] || [ "$(uname)" = "Darwin" ]; then
		run_godot 900 --path . -s res://tools/screenshot.gd
		grep "RENDER" "$TMP_OUT" | sed 's/^/    /'
		if grep -q "RENDER DONE" "$TMP_OUT" && ! grep -q "RENDER FAIL" "$TMP_OUT" && ! grep -qE "$ERR_RE" "$TMP_OUT"; then echo "  ok  render smoke (screenshots in shots/)"
		else fail "render smoke"; show_errors; fi
	else echo "  WARNING: no display available; render smoke skipped"; fi
	VSHORT="$(echo "$VER" | cut -d. -f1-4)"
	if [ "${OS:-}" = "Windows_NT" ]; then TPL="$APPDATA/Godot/export_templates/$VSHORT"
	elif [ "$(uname)" = "Darwin" ]; then TPL="$HOME/Library/Application Support/Godot/export_templates/$VSHORT"
	else TPL="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VSHORT"; fi
	if [ -f "$TPL/windows_release_x86_64.exe" ] && [ -f "$TPL/linux_release.x86_64" ]; then
		if bash tools/export.sh --dry-run; then echo "  ok  export dry run"; else fail "export dry run"; fi
	else echo "  WARNING: export templates not installed at $TPL; export dry run skipped"; fi
fi

rm -f "$TMP_OUT"
if [ $PROBLEMS -eq 0 ]; then echo "VERIFY: ALL GREEN"; exit 0
else echo "VERIFY: FAILED ($PROBLEMS problems)"; exit 1; fi
