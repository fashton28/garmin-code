#!/usr/bin/env bash
# Compile the Connect IQ watch app (apps/watch) for the Forerunner 165.
# Local-only: requires the Garmin Connect IQ SDK and a developer key.
#
# Override via env vars if your paths differ:
#   CIQ_SDK_BIN   - path to the SDK's bin/ dir (containing monkeyc)
#   CIQ_DEV_KEY   - path to your developer_key
#   CIQ_DEVICE    - target device id (default: fr165)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WATCH_DIR="$REPO_ROOT/apps/watch"

CIQ_DEVICE="${CIQ_DEVICE:-fr165}"
CIQ_DEV_KEY="${CIQ_DEV_KEY:-$HOME/development/developer_key}"

# Auto-discover the newest installed SDK bin if not provided.
if [[ -z "${CIQ_SDK_BIN:-}" ]]; then
  SDK_ROOT="$HOME/Library/Application Support/Garmin/ConnectIQ/Sdks"
  CIQ_SDK_BIN="$(ls -d "$SDK_ROOT"/*/bin 2>/dev/null | sort | tail -1 || true)"
fi

if [[ -z "${CIQ_SDK_BIN:-}" || ! -x "$CIQ_SDK_BIN/monkeyc" ]]; then
  echo "error: monkeyc not found. Set CIQ_SDK_BIN to your Connect IQ SDK bin/ dir." >&2
  exit 1
fi
if [[ ! -f "$CIQ_DEV_KEY" ]]; then
  echo "error: developer key not found at $CIQ_DEV_KEY. Set CIQ_DEV_KEY." >&2
  exit 1
fi

CONFIG_FILE="$WATCH_DIR/source/Config.mc"
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Config.mc missing; seeding from Config.mc.example (edit it with your real values)."
  cp "$CONFIG_FILE.example" "$CONFIG_FILE"
fi

mkdir -p "$WATCH_DIR/bin"
echo "Building apps/watch for device '$CIQ_DEVICE'..."
"$CIQ_SDK_BIN/monkeyc" \
  --jungles "$WATCH_DIR/monkey.jungle" \
  --device "$CIQ_DEVICE" \
  --output "$WATCH_DIR/bin/ClaudeWatch.prg" \
  --private-key "$CIQ_DEV_KEY" \
  --warn
echo "BUILD SUCCESSFUL -> apps/watch/bin/ClaudeWatch.prg"
