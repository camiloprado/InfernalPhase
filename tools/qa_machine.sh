#!/usr/bin/env bash
# Locate Godot 4.7.2 and run Infernal Phase look/proof + combat QA.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -n "${GODOT:-}" && -x "$GODOT" ]]; then
  :
elif [[ -x "$HOME/.local/bin/godot" ]]; then
  GODOT="$HOME/.local/bin/godot"
elif command -v godot >/dev/null 2>&1; then
  GODOT="$(command -v godot)"
else
  echo "FAIL: godot not found (set GODOT or install to ~/.local/bin/godot)"
  exit 127
fi
export GODOT
export DISPLAY="${DISPLAY:-:0}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-dummy}"

echo "GODOT=$GODOT"
"$GODOT" --version || true
echo "DISPLAY=$DISPLAY"

ARGS=(-- --qa-look --qa-proof --qa-combat)
if [[ "${1:-}" == "--combat" ]]; then
  ARGS=(-- --qa-combat)
elif [[ "${1:-}" == "--look" ]]; then
  ARGS=(-- --qa-look --qa-proof)
fi

set +e
if command -v xvfb-run >/dev/null 2>&1 && [[ "${QA_FORCE_DISPLAY:-}" != "1" ]]; then
  echo "driver=xvfb-run"
  timeout 180 xvfb-run -a -s "-screen 0 1280x720x24" ./run.sh "${ARGS[@]}"
  EC=$?
else
  echo "driver=DISPLAY"
  timeout 180 ./run.sh "${ARGS[@]}"
  EC=$?
fi
set -e
echo "QA_EXIT=$EC"
if [[ $EC -eq 0 ]]; then
  echo "PASS"
else
  echo "FAIL"
fi
exit "$EC"
