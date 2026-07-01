# Integration & validation (I1 / I2)

How to run ClaudeWatch end-to-end - first in the simulator (I1), then on the real Forerunner 165 (I2).

## I1 - End-to-end in the simulator

The Connect IQ simulator makes `makeWebRequest` calls **directly from your Mac's network** (no phone bridge), and it allows plain `http://localhost`.
So you can point the watch app at a local daemon serving your real `~/.claude` sessions.

### One command

```bash
tools/dev/run-sim.sh      # Ctrl-C to tear down
```

This script (idempotent, and it backs up/restores your real `Config.mc`):

1. Starts the daemon on `:8787` (if one isn't already running) serving your real sessions.
2. Writes a temporary `Config.mc` pointing at `http://localhost:8787`.
3. Builds the watch app for `fr165`.
4. Launches the simulator and loads the app.
5. Blocks so the daemon stays up while you use the sim; Ctrl-C stops the daemon and restores your `Config.mc`.

### What you should see

The **Sessions** menu: a **Refresh** row on top, then your most-recent sessions, e.g.
`Review entire repository for context` / `8m ago - sonar`, with a `* ` marker on active ones.
Select **Refresh** (or the error/empty screen) to re-fetch.

### Status

Verified working: the simulator renders real session data from the local daemon, newest-first, with relative-time sub-labels, the active marker, and working refresh/retry.

## I2 - Sideload to the Forerunner 165

The real watch has **no WiFi/LTE**, so `makeWebRequest` is tunneled through the **Garmin Connect** app on your phone over BLE, then out to the internet.
That means the device needs a **public HTTPS URL with a valid cert** - your Cloudflare tunnel from B3, not `http://localhost`.

### 1. Bring up the public daemon (B3)

```bash
# one-time Cloudflare setup - see tools/tunnel/README.md
npm run serve:tunnel      # daemon + cloudflared, serving https://<your-hostname>
```

### 2. Point the watch app at the tunnel

Edit `apps/watch/source/Config.mc` (git-ignored):

```
BASE_URL = "https://<your-tunnel-hostname>"   // no trailing slash
TOKEN    = "<same token as the daemon>"
```

### 3. Build the device app

```bash
npm run build:watch       # produces apps/watch/bin/ClaudeWatch.prg (signed with your developer key)
```

### 4. Sideload over USB

1. Connect the FR165 to your Mac with the USB cable; it mounts as a `GARMIN` drive.
2. Copy `apps/watch/bin/ClaudeWatch.prg` into the drive's `GARMIN/APPS/` folder.
3. Eject the drive and disconnect.
4. On the watch, open the app from the app/activity list.

(Alternatively, in VS Code: **Monkey C: Build for Device** / the extension's *Run on Device*.)

### 5. Validate on-wrist

- **Phone present, Garmin Connect running, in range** → your sessions render, just like the sim.
- **Phone out of range / Connect not running** → the app should land on the error screen ("Phone not connected") with **press-to-retry**.
- Check the app's memory use is within the FR165 budget (the simulator's memory viewer is the quickest proxy).

### Status

Prepared: the device-signed `.prg` builds cleanly for `fr165`, and the tunnel + config path is documented.
The physical sideload + on-wrist checks are yours to run (they need the watch + USB).
