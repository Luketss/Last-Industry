#!/usr/bin/env bash
# Runs the headless test suite. Any engine-reported script error fails the run,
# because GDScript runtime errors do not abort a test method on their own.
set -uo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --path . --import >/dev/null 2>&1 || true
out="$("$GODOT" --headless --path . -s res://tests/run_tests.gd 2>&1)"
code=$?
echo "$out" | grep -v '^Godot Engine'
if echo "$out" | grep -qE 'SCRIPT ERROR|Parse Error|Compile Error'; then
	echo "ERRO: erros de script detectados durante os testes" >&2
	exit 1
fi
exit $code
