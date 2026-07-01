# ClaudeWatch

Monitor and drive your Claude Code sessions from a Garmin Forerunner 165.

A small daemon on your Mac reads your local Claude Code session history and exposes it over an authenticated HTTPS API.
A Connect IQ watch app fetches that API and lets you, from your wrist:

- **See your recent sessions** with a live state dot (working / waiting for you / idle), the AI-generated title, relative last-active time, and the model the session uses.
- **Run a task in a session** - Create PR, Run tests, or Review code - headlessly, with a live status screen (spinner, model, and an outcome message).
- **View overall usage** - a dashboard of total tokens, sessions, messages, and a per-model breakdown.

Everything is styled in a terminal / "computer" aesthetic: a custom 0xProto monospace font, an orange focus accent, and a Claude spark.

## Demo

<video src="https://github.com/fashton28/garmin-code/raw/main/docs/demo.mp4" controls width="320"></video>

> If the video does not play inline, [watch it here](https://github.com/fashton28/garmin-code/raw/main/docs/demo.mp4).

## How it works

```
Forerunner 165 (Monkey C app)
    -> makeWebRequest (HTTPS + bearer token), relayed through the phone over BLE
    -> the Garmin Connect app on your phone (the internet bridge)
    -> a public HTTPS URL (Cloudflare tunnel / Tailscale Funnel)
    -> daemon on your Mac (Node + TypeScript)
    -> reads ~/.claude/projects/*/*.jsonl  and  runs `claude -p` for tasks
```

Two facts drive the whole design.

1. The FR165 has **no WiFi and no LTE**.
   Every network request is tunneled through the **Garmin Connect app on your phone** over Bluetooth, then out to the internet.
   So the phone must be nearby, connected, and running Garmin Connect.
2. The daemon must run on the **machine where your Claude Code work actually lives**.
   It reads session transcripts from your local `~/.claude` and runs tasks by spawning `claude -p` in your local repos.
   It cannot be offloaded to a generic cloud box, because that box would only see its own sessions and repos.

## Requirements

- **macOS** (or another machine where you run Claude Code) with **Node 20+**.
- The **Claude Code CLI** (`claude`) installed and authenticated - required for the task feature.
- **Garmin Connect IQ SDK** and a **developer key** (`~/development/developer_key`), to build the watch app.
- A **Garmin Forerunner 165** and its **data cable**, for real-device use.
- Your **phone** with the Garmin Connect app, paired to the watch.
- A way to expose the daemon over public HTTPS (a Cloudflare tunnel or Tailscale Funnel - see [Exposing the daemon](#exposing-the-daemon)).

## Quick start (simulator)

The fastest way to see it working, entirely on your Mac, no phone or tunnel needed.

```bash
git clone https://github.com/fashton28/garmin-code
cd garmin-code
npm ci                 # installs the daemon workspace
npm run sim            # daemon + simulator + app, all wired to your real sessions
```

`npm run sim` starts a local daemon serving your real `~/.claude` sessions, points the watch app at `http://localhost:8787`, builds it, launches the Connect IQ simulator, and loads the app.
Press **Ctrl-C** to tear it all down (it restores your `Config.mc`).

Why this works without a tunnel: the **simulator makes web requests directly from your Mac's network**, so plain `http://localhost` is fine.
The real watch is different (see below).

## Getting it on the real Forerunner 165

There are four steps: a public HTTPS endpoint, the config, the build, and the sideload.

### 1. Expose the daemon over public HTTPS

The real watch needs a **public HTTPS URL with a valid certificate** (plain `localhost` only works in the simulator).
Pick one:

| Option | Stable URL | Cost | Notes |
|--------|-----------|------|-------|
| Cloudflare **quick tunnel** | No (rotates each restart) | Free | Fastest to try; the URL changes when `cloudflared` restarts, which means editing `Config.mc` + rebuilding + re-sideloading. |
| Cloudflare **named tunnel** | Yes | ~$1-12/yr (a domain) | Stable hostname; see `tools/tunnel/README.md`, then `npm run serve:tunnel`. |
| **Tailscale Funnel** | Yes | Free | Stable `https://<host>.<tailnet>.ts.net`, no domain needed. |

Quick tunnel (to try it out):

```bash
brew install cloudflared
cloudflared tunnel --url http://localhost:8787       # prints a https://<random>.trycloudflare.com URL
```

Keep this process running - the watch reaches the daemon only while it is up.

### 2. Point the watch app at it (and share the token)

The watch and daemon authenticate with a shared bearer token.
Generate one, put it in the daemon's env, and put the **same** token plus your tunnel URL in the watch config.

```bash
# daemon side (git-ignored)
printf 'CLAUDEWATCH_TOKEN=%s\nPORT=8787\n' "$(openssl rand -hex 32)" > apps/daemon/.env
```

Then edit `apps/watch/source/Config.mc` (git-ignored - copy from `Config.mc.example` if missing):

```monkeyc
const BASE_URL as Lang.String = "https://<your-tunnel-hostname>";   // no trailing slash
const TOKEN    as Lang.String = "<the same token as apps/daemon/.env>";
const LIMIT    as Lang.Number = 10;
```

The token in `Config.mc` **must match** `CLAUDEWATCH_TOKEN` in `apps/daemon/.env`, or every request returns 401.

### 3. Build the device app

```bash
# run the daemon (reads the token from apps/daemon/.env)
npm run serve
# ...and the tunnel in another terminal (step 1)

# build the signed .prg
npm run build:watch      # -> apps/watch/bin/ClaudeWatch.prg
```

Before it builds, confirm the public URL is reachable end to end:

```bash
curl -s -o /dev/null -w '%{http_code}\n' -H "Authorization: Bearer <token>" "https://<your-tunnel-hostname>/sessions?limit=1"   # expect 200
```

### 4. Sideload to the watch

The `.prg` is just a file the watch reads from `GARMIN/APPS/`.
**The catch on macOS:** the FR165 connects over **MTP**, not USB mass storage, so it does **not** mount as a drive in `/Volumes`, and you can't copy to it from the macOS terminal / Finder.

Choose the easiest working path:

- **Windows (easiest):** plug the watch in, open **File Explorer -> This PC -> Forerunner 165 -> Internal Storage -> GARMIN -> APPS**, and paste `ClaudeWatch.prg` there.
- **macOS via [openMTP](https://openmtp.ganeshrvel.com):** a free MTP app that handles Garmin well (Android File Transfer is unreliable with Garmin). Browse the watch -> `GARMIN/APPS` and drop the `.prg` in.

Put `ClaudeWatch.prg` directly in `GARMIN/APPS/` (not a subfolder), eject cleanly, then open **ClaudeWatch** from the watch's app/glance list.
If it isn't listed, **reboot the watch** (it rescans `GARMIN/APPS` on boot).

### 5. Use it

- Keep the **daemon + tunnel running** on your Mac, and keep the Mac **awake and online**.
- Keep your **phone nearby, Bluetooth on, Garmin Connect running**.
- Open **ClaudeWatch**.
  It loads your session list.
  From a session you can run a task; the **Usage** row (under Refresh) opens the dashboard.

You can use it away from home as long as your phone has internet and your Mac stays up with the daemon + tunnel alive.

## Session state (optional accuracy)

Each session shows a state: **working** (green), **waiting for you** (yellow), or **idle** (gray).

By default this is a heuristic from the transcript's freshness and last turn, which is good but approximate (a long silent operation can read as idle).
For exact, real-time state, enable the optional Claude Code hooks described in [`docs/session-state.md`](docs/session-state.md) - they report `working`/`waiting` as they happen and override the heuristic.

## Tasks and security

Selecting **Create PR / Run tests / Review code** spawns `claude -p` headlessly **in that session's working directory** with a fixed prompt, a **scoped `--allowedTools`** allowlist, and `--permission-mode acceptEdits` (so no interactive prompt can block it).

These are **real actions on your machine**: Create PR really commits, pushes, and opens a PR; Run tests runs your test command.
Because the endpoint is behind a **public tunnel**, the bearer token is genuinely load-bearing.

- Use a **strong, secret token**.
- The per-task tool allowlists keep the blast radius tight (e.g. Create PR gets only `git`/`gh`).
- **Review code** is read-only and the safest to try first.

## The API

The daemon serves a small, frozen contract (`contract/contract.md`), guarded by `Authorization: Bearer <token>`:

| Method + path | Purpose |
|---------------|---------|
| `GET /sessions?limit=10` | The recent sessions (id, project, title, lastActive, messages, active, state, model). |
| `POST /sessions/:id/tasks` | Start a task (`{ "task": "create_pr" \| "run_tests" \| "review" }`); returns a `taskId`. |
| `GET /tasks/:id` | Poll a task: `status` (running/done/failed), `summary`, `model`. |
| `GET /usage` | Aggregate usage: sessions, messages, token totals, per-model breakdown. |

Validate the canonical fixture any time with `node contract/validate.mjs`.

## Configuration reference

Both config files are **git-ignored**; commit nothing with real secrets.

**`apps/daemon/.env`** (loaded automatically by the daemon):

| Var | Default | Meaning |
|-----|---------|---------|
| `CLAUDEWATCH_TOKEN` | (required) | Shared bearer token. The server rejects every request if unset. |
| `PORT` | `8787` | Listen port. |
| `CLAUDE_PROJECTS_DIR` | `~/.claude/projects` | Where to read session transcripts. |
| `CLAUDEWATCH_STATE_DIR` | `~/.claude/claudewatch-state` | Where the optional state hooks write. |

**`apps/watch/source/Config.mc`**: `BASE_URL`, `TOKEN` (must match the daemon), `LIMIT`.

The watch build (`tools/build-watch.sh`) auto-discovers the newest installed SDK; override with `CIQ_SDK_BIN`, `CIQ_DEV_KEY`, `CIQ_DEVICE` if your paths differ.

## Keeping it always-on (optional)

The current setup runs in a terminal and dies when the session ends or the Mac sleeps.
For a durable, hands-off setup:

- A **`launchd`** LaunchAgent so the daemon auto-starts on boot and restarts on crash.
- **`caffeinate`** (or `pmset`) so the Mac never sleeps and drops the tunnel.
- A **stable URL** via a named Cloudflare tunnel (needs a domain) or **Tailscale Funnel** (free), so you never rebuild the `.prg` for a URL change again.

The Mac still has to be powered and online, because that is where your sessions and repos live.

## Troubleshooting

**"Can't load" / "Phone not connected" on the watch.**
The phone bridge isn't live.
Make sure the phone is nearby, Bluetooth is on, the Garmin Connect app is running, and the phone has internet.
Press Start on the error screen to retry.

**Everything returns 401.**
The token in `apps/watch/source/Config.mc` doesn't match `CLAUDEWATCH_TOKEN` in `apps/daemon/.env`.
Fix the token, rebuild the `.prg`, and re-sideload.

**The watch won't mount as a drive on macOS.**
The FR165 uses MTP, not mass storage - this is expected.
Use a Windows PC (native MTP in File Explorer) or [openMTP](https://openmtp.ganeshrvel.com) on the Mac.

**The Mac shows only a "BillBoard Device" and no Garmin.**
The USB connection is charge-only.
Use the Garmin data cable, and if you go through a USB-A to USB-C adapter, use a data-capable one plugged directly into the Mac.

**The app isn't in the watch's app list.**
Reboot the watch so it rescans `GARMIN/APPS`, and confirm `ClaudeWatch.prg` is directly inside `GARMIN/APPS/`.

**The watch app stopped reaching the daemon after some time.**
A quick tunnel URL rotates when `cloudflared` restarts (Mac sleep, terminal close).
Restart the tunnel, update `BASE_URL`, rebuild, re-sideload - or move to a named tunnel / Tailscale Funnel for a stable URL.

**A session shows no model.**
Fresh sessions that haven't had a real (non-synthetic) assistant turn yet have no recorded model; it fills in once the session runs.

**A task fails immediately.**
Confirm `claude` is on the daemon's `PATH` and authenticated, and that the task's cwd is a real repo (for Create PR you also need `gh` authenticated).

## Repository layout

| Path | What it is |
|------|------------|
| `contract/` | The frozen HTTP+JSON contract and the canonical `sessions.json` fixture both sides build against. |
| `apps/daemon/` | Node + TypeScript daemon (the only npm workspace): reads sessions, serves the API, runs tasks. |
| `apps/watch/` | Connect IQ (Monkey C) app for the Forerunner 165. |
| `tools/tunnel/` | Cloudflare tunnel config + run scripts (`npm run serve:tunnel`). |
| `tools/dev/run-sim.sh` | The `npm run sim` harness (local daemon + simulator). |
| `tools/fonts/gen_font.py` | Generates the custom 0xProto bitmap fonts from a TTF. |
| `tools/hooks/` | The optional session-state hook. |
| `docs/` | `integration.md` (sim + sideload) and `session-state.md` (state + hooks). |

## Development

```bash
npm ci               # install the daemon workspace
npm test             # daemon tests
npm run typecheck
npm run build        # daemon build
npm run list         # print your recent sessions as JSON (no watch needed)
```

CI (`.github/workflows/ci.yml`) runs the daemon typecheck, tests, and build on every push and PR to `main`.
The watch app is not built in CI (it needs the Garmin SDK + developer key); build it locally with `npm run build:watch`.
