#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_BIN="$ROOT/bin/godot"
BIN="${GODOT_BIN:-$DEFAULT_BIN}"
GODOT_VERSION="4.2.2-stable"
GODOT_ARCHIVE="Godot_v${GODOT_VERSION}_linux.x86_64.zip"
GODOT_URL="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}/${GODOT_ARCHIVE}"

if [ ! -x "$BIN" ]; then
	if [ "$BIN" != "$DEFAULT_BIN" ]; then
		echo "Godot CLI not found at $BIN. Provide a valid path via GODOT_BIN." >&2
		exit 1
	fi
	echo "Godot CLI not found. Downloading Godot ${GODOT_VERSION}..."
	tmpdir="$(mktemp -d)"
	archive_path="$tmpdir/$GODOT_ARCHIVE"
	if ! curl -L -o "$archive_path" "$GODOT_URL"; then
		echo "Failed to download Godot from $GODOT_URL" >&2
		rm -rf "$tmpdir"
		exit 1
	fi
	if ! unzip -q "$archive_path" -d "$tmpdir"; then
		echo "Failed to extract $GODOT_ARCHIVE" >&2
		rm -rf "$tmpdir"
		exit 1
	fi
	extracted="$tmpdir/Godot_v${GODOT_VERSION}_linux.x86_64"
	if [ ! -f "$extracted" ]; then
		echo "Extracted binary not found at $extracted" >&2
		rm -rf "$tmpdir"
		exit 1
	fi
	mkdir -p "$(dirname "$DEFAULT_BIN")"
	if ! install -m 755 "$extracted" "$DEFAULT_BIN"; then
		echo "Failed to install Godot CLI to $DEFAULT_BIN" >&2
		rm -rf "$tmpdir"
		exit 1
	fi
	rm -rf "$tmpdir"
	echo "Godot CLI installed at $DEFAULT_BIN"
fi

exec "$BIN" --headless --path "$ROOT" --script "res://tests/test_runner.gd"
