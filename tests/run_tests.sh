#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${GODOT_BIN:-$ROOT/bin/godot}"

if [ ! -x "$BIN" ]; then
	echo "Godot CLI not found. Place the headless binary at $ROOT/bin/godot or set GODOT_BIN to the executable path."
	exit 1
fi

exec "$BIN" --headless --path "$ROOT" --script "res://tests/test_runner.gd"
