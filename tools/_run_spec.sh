#!/usr/bin/env bash
set -uo pipefail
ROOT="/home/camil/InfernalPhase"
LOG="/tmp/infernal_qa_spec.log"
cd "$ROOT"
export GODOT="${GODOT:-$HOME/.local/bin/godot}"
export DISPLAY="${DISPLAY:-:0}"
export SDL_AUDIODRIVER="${SDL_AUDIODRIVER:-dummy}"
echo "=== spec QA $(date -Is) ===" | tee "$LOG"
"$GODOT" --version 2>&1 | tee -a "$LOG"
set +e
timeout 180 ./run.sh -- --qa-spec 2>&1 | tee -a "$LOG"
EC=${PIPESTATUS[0]}
echo "QA_SPEC_EXIT=$EC" | tee -a "$LOG"
exit 0
