# Session state (Working / Waiting / Idle)

Each session in the `/sessions` response carries a `state`:

| State       | Meaning                                              |
|-------------|------------------------------------------------------|
| `working`   | Claude is actively processing.                       |
| `waiting`   | Claude finished a turn and is waiting for your input.|
| `idle`      | No recent activity.                                  |

The daemon derives this **hybridly** - accurate hook data when available, a heuristic otherwise.

## Heuristic (always on, no setup)

From the session file's freshness and its last conversation turn (thresholds in `apps/daemon/src/config.ts`):

- touched within 30s → `working` (the transcript is actively being appended)
- user spoke last, within 5m → `working` (input pending; Claude is presumably running)
- assistant spoke last, within 10m → `waiting` (your move)
- otherwise → `idle`

This works for every session immediately, but it's approximate: during a long silent operation (no transcript writes for a while) a `working` session can briefly read as `idle`.

## Hooks (optional, accurate)

Claude Code lifecycle hooks report the real state as it changes. When a **fresh** hook state exists for a session it **overrides** the heuristic; stale hook states (older than 6h) are ignored so an abandoned "working" session doesn't stick.

`tools/hooks/claudewatch-hook.mjs <state>` reads the hook payload on stdin and writes
`~/.claude/claudewatch-state/<session_id>.json`. It fails open (never blocks Claude).

### Enable it

Add these to your Claude Code settings (`~/.claude/settings.json`), replacing
`/ABSOLUTE/PATH/TO/garmin-code` with this repo's absolute path:

```json
{
  "hooks": {
    "UserPromptSubmit": [
      { "hooks": [{ "type": "command", "command": "node /ABSOLUTE/PATH/TO/garmin-code/tools/hooks/claudewatch-hook.mjs working" }] }
    ],
    "Stop": [
      { "hooks": [{ "type": "command", "command": "node /ABSOLUTE/PATH/TO/garmin-code/tools/hooks/claudewatch-hook.mjs waiting" }] }
    ],
    "Notification": [
      { "hooks": [{ "type": "command", "command": "node /ABSOLUTE/PATH/TO/garmin-code/tools/hooks/claudewatch-hook.mjs waiting" }] }
    ]
  }
}
```

- **UserPromptSubmit** → `working` (you submitted a prompt; Claude starts working).
- **Stop** → `waiting` (Claude finished its turn).
- **Notification** → `waiting` (Claude needs input or a permission decision).

After editing settings, open `/hooks` once (or restart Claude Code) so the config reloads.

The daemon reads state files from `~/.claude/claudewatch-state` by default; override with `CLAUDEWATCH_STATE_DIR` (set it for both the hook and the daemon).
