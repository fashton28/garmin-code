# garmin-code / ClaudeWatch

Run and manage your Claude Code sessions directly from your Garmin Forerunner 165.

**v1 (current): read-only.** List your 10 most recent Claude Code sessions on the wrist.
Running sessions from the watch is planned for v2.

## How it works

```
Forerunner 165 (Monkey C app)
    -> makeWebRequest (HTTPS, bearer token), tunneled through the phone over BLE
    -> Cloudflare Tunnel (public HTTPS)
    -> Daemon on Mac (Node + TypeScript)
    -> reads ~/.claude/projects/*/*.jsonl
```

The watch has no WiFi/LTE, so every request goes through the Garmin Connect app on the phone.
The phone must be nearby and connected.

## Repository layout

| Path              | What it is |
|-------------------|------------|
| `contract/`       | The frozen HTTP+JSON contract and the canonical `sessions.json` fixture both sides build against. |
| `apps/daemon/`    | Node + TypeScript daemon that reads session history and serves the API. |
| `apps/watch/`     | Connect IQ (Monkey C) device app for the Forerunner 165. |
| `tools/tunnel/`   | Cloudflare tunnel config and run scripts. |

The planning doc lives at `PRD.md` (kept local, git-ignored).

## Contract first

The API contract is frozen in `contract/contract.md`.
Validate the canonical fixture any time:

```
node contract/validate.mjs
```

Both apps are developed in parallel against this contract, then wired together in the integration milestone.

## Getting started

Config is supplied via git-ignored files with committed `.example` siblings:

- Daemon: copy `apps/daemon/.env.example` to `apps/daemon/.env`.
- Watch: copy `apps/watch/source/Config.mc.example` to `apps/watch/source/Config.mc`.

Use the **same token** in both.
