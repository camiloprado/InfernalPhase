#!/usr/bin/env bash
# Install Godot 4.7.2 standard (not .NET) for Infernal Phase on this Linux.
set -euo pipefail
VER="4.7.2"
BIN="${GODOT_BIN:-$HOME/.local/bin/godot}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/godot-install"
URL="https://github.com/godotengine/godot/releases/download/${VER}-stable/Godot_v${VER}-stable_linux.x86_64.zip"

mkdir -p "$(dirname "$BIN")" "$CACHE"
if [[ -x "$BIN" ]]; then
  if "$BIN" --version 2>/dev/null | grep -q "$VER"; then
    echo "GODOT_OK path=$BIN version=$("$BIN" --version)"
    exit 0
  fi
fi

zip="$CACHE/Godot_v${VER}-stable_linux.x86_64.zip"
if [[ ! -s "$zip" ]]; then
  echo "Downloading $URL"
  wget -q --show-progress -O "$zip" "$URL"
fi
tmp="$(mktemp -d)"
unzip -qo "$zip" -d "$tmp"
src="$(find "$tmp" -type f -name 'Godot_v*' | head -n 1)"
install -m 0755 "$src" "$BIN"
rm -rf "$tmp"
echo "GODOT_OK path=$BIN version=$("$BIN" --version)"
