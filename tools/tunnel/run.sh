#!/usr/bin/env bash
# Run the ClaudeWatch daemon and its Cloudflare named tunnel together (issue B3).
#
# Starts `npm run serve` (the daemon on PORT, default 8787) in the background,
# then runs `cloudflared tunnel --config tools/tunnel/config.yml run` in the
# foreground so the public HTTPS hostname reaches the local daemon. Stopping
# this script (Ctrl-C / any exit) cleanly kills the backgrounded daemon.
#
# Prerequisites (one-time, see tools/tunnel/README.md):
#   - cloudflared installed and `cloudflared tunnel login` completed
#   - `cloudflared tunnel create claudewatch` run and DNS routed
#   - tools/tunnel/config.yml created from config.example.yml and filled in
#   - CLAUDEWATCH_TOKEN set (env or apps/daemon/.env), matching the watch TOKEN
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TUNNEL_DIR="$REPO_ROOT/tools/tunnel"
CONFIG_FILE="$TUNNEL_DIR/config.yml"

# --- Preflight checks -------------------------------------------------------

if ! command -v cloudflared >/dev/null 2>&1; then
  echo "error: cloudflared not found. Install it first, e.g. 'brew install cloudflared'." >&2
  echo "       See tools/tunnel/README.md for the one-time setup." >&2
  exit 1
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "error: $CONFIG_FILE not found." >&2
  echo "       Copy tools/tunnel/config.example.yml to tools/tunnel/config.yml and" >&2
  echo "       fill in your tunnel id, credentials path, and hostname." >&2
  exit 1
fi

# The daemon refuses to start without CLAUDEWATCH_TOKEN. It can come from the
# environment or apps/daemon/.env; warn early if we can find neither.
if [[ -z "${CLAUDEWATCH_TOKEN:-}" ]] && ! grep -q '^CLAUDEWATCH_TOKEN=' "$REPO_ROOT/apps/daemon/.env" 2>/dev/null; then
  echo "error: CLAUDEWATCH_TOKEN is not set and apps/daemon/.env has no CLAUDEWATCH_TOKEN." >&2
  echo "       Export it (export CLAUDEWATCH_TOKEN=...) or set it in apps/daemon/.env." >&2
  echo "       It must match TOKEN in apps/watch/source/Config.mc." >&2
  exit 1
fi

# --- Start daemon, then tunnel ---------------------------------------------

PORT="${PORT:-8787}"

DAEMON_PID=""
cleanup() {
  if [[ -n "$DAEMON_PID" ]] && kill -0 "$DAEMON_PID" 2>/dev/null; then
    echo "Stopping daemon (pgid $DAEMON_PID)..."
    kill -TERM -"$DAEMON_PID" 2>/dev/null || true
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      kill -0 "$DAEMON_PID" 2>/dev/null || break
      sleep 0.5
    done
    kill -KILL -"$DAEMON_PID" 2>/dev/null || true
    wait "$DAEMON_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# Enable job control so the backgrounded daemon runs in its own process group
# (pgid == the subshell pid). That lets cleanup() signal the whole tree - npm
# and node included - rather than just the subshell, which npm would not
# forward to node, leaking the daemon and holding port "$PORT".
set -m

echo "Starting daemon (npm run serve)..."
( cd "$REPO_ROOT" && npm run serve ) &
DAEMON_PID=$!

set +m

# Wait until the daemon is actually listening before starting cloudflared,
# rather than assuming a fixed startup delay. Bail out early if it dies.
echo "Waiting for daemon to listen on port $PORT..."
ready=""
for _ in $(seq 1 20); do
  if ! kill -0 "$DAEMON_PID" 2>/dev/null; then
    echo "error: daemon exited during startup. Check the output above." >&2
    exit 1
  fi
  # /sessions is token-guarded and answers 401 without a token; that still
  # proves the port is bound. Any real HTTP status counts as listening - only
  # the connection-failure sentinel 000 means the daemon is not up yet.
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://localhost:$PORT/sessions?limit=1" 2>/dev/null || true)"
  if [[ -n "$code" && "$code" != "000" ]]; then
    ready="yes"
    break
  fi
  sleep 0.5
done

if [[ -z "$ready" ]]; then
  echo "error: daemon did not start listening on port $PORT within 10s." >&2
  exit 1
fi

echo "Starting Cloudflare tunnel..."
cloudflared tunnel --config "$CONFIG_FILE" run
