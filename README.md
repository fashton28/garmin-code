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
| `tools/build-watch.sh` | Local-only script that compiles the watch app with the Connect IQ SDK. |

The repository is an npm workspace monorepo (root `package.json`), currently
containing the `apps/daemon` workspace.

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

## Building and testing

Install everything from the repo root (`npm ci` installs all workspaces).
The root scripts fan out across workspaces:

```
npm test         # run each workspace's tests
npm run typecheck
npm run build
npm run list     # daemon: list the 10 most recent sessions
```

CI (`.github/workflows/ci.yml`) runs the daemon typecheck, tests, and build on
every push and pull request to `main`.

The watch app is **not** built in CI - it needs the Garmin Connect IQ SDK and a
developer key. Build it locally instead:

```
npm run build:watch
```

This runs `tools/build-watch.sh`, which auto-discovers the newest installed SDK.
Override the defaults with the `CIQ_SDK_BIN`, `CIQ_DEV_KEY`, and `CIQ_DEVICE`
environment variables if your paths differ. The compiled app lands at
`apps/watch/bin/ClaudeWatch.prg`.

If `Config.mc` is missing, the build seeds a placeholder from
`Config.mc.example` so the compile succeeds; edit it with your real tunnel URL
and token before the app can reach the daemon.

## Exposing the daemon (Cloudflare tunnel)

The watch reaches the daemon through a stable public HTTPS URL served by a
Cloudflare named tunnel. See `tools/tunnel/README.md` for the one-time setup,
then run both the daemon and the tunnel together:

```
npm run serve:tunnel
```

## Running end-to-end

To see the watch app render your real sessions in the **simulator** against a
local daemon (one command, tears down on Ctrl-C):

```
npm run sim
```

For the full walkthrough - simulator (I1) and sideloading to the physical
Forerunner 165 (I2) - see [`docs/integration.md`](docs/integration.md).
