# Cloudflare tunnel for ClaudeWatch

The Garmin watch has no WiFi/LTE, so `makeWebRequest` needs a **stable public HTTPS URL** that reaches the daemon running on your Mac (`apps/daemon`, `npm run serve`, `http://localhost:8787`).
We use a **Cloudflare named tunnel**: a persistent tunnel with a fixed hostname you own, rather than a throwaway `trycloudflare.com` URL that changes every run.

```
watch --HTTPS--> <your-hostname> (Cloudflare) --tunnel--> cloudflared on Mac --> http://localhost:8787
```

## One-time setup

You run these once, on the Mac that will host the daemon.
They need **your** Cloudflare account and an interactive browser login, so they are not scripted here.

1. **Install cloudflared**

   ```
   brew install cloudflared
   ```

2. **Log in** (opens a browser; pick the zone/domain you control). This writes `~/.cloudflared/cert.pem`.

   ```
   cloudflared tunnel login
   ```

3. **Create the named tunnel.** This prints a tunnel **UUID** and writes its credentials to `~/.cloudflared/<TUNNEL-ID>.json`.

   ```
   cloudflared tunnel create claudewatch
   ```

4. **Create your config** from the template and fill in the three placeholders (tunnel id, credentials-file path, hostname):

   ```
   cp tools/tunnel/config.example.yml tools/tunnel/config.yml
   ```

5. **Route DNS** to the tunnel. Use a hostname on a domain in your Cloudflare account (e.g. `claudewatch.example.com`). This must match the `hostname:` in `config.yml`.

   ```
   cloudflared tunnel route dns claudewatch claudewatch.example.com
   ```

6. **Set the shared token.** The daemon refuses to start without `CLAUDEWATCH_TOKEN`. Put it in `apps/daemon/.env` (copy from `.env.example`) or export it:

   ```
   export CLAUDEWATCH_TOKEN="$(openssl rand -hex 32)"
   ```

## Running

From the repo root:

```
npm run serve:tunnel
```

or directly:

```
tools/tunnel/run.sh
```

This starts the daemon (`npm run serve`) in the background and the tunnel in the foreground.
Press Ctrl-C to stop both (the script kills the backgrounded daemon on exit).

## Wiring the watch (Config.mc)

The tunnel is the bridge between the two config files. They must agree:

| Watch (`apps/watch/source/Config.mc`) | Daemon (`apps/daemon/.env`) | Tunnel (`tools/tunnel/config.yml`) |
|---------------------------------------|-----------------------------|------------------------------------|
| `BASE_URL = "https://<hostname>"`     | -                           | `ingress[0].hostname: <hostname>`  |
| `TOKEN = "<token>"`                   | `CLAUDEWATCH_TOKEN=<token>` | -                                  |

- **`BASE_URL`** is your public tunnel hostname with `https://` and **no trailing slash** - the same hostname you routed DNS to and put in `config.yml`.
- **`TOKEN`** must be byte-for-byte the same as the daemon's `CLAUDEWATCH_TOKEN`; the watch sends it as `Authorization: Bearer <token>` and the daemon rejects anything else with 401.

## Secrets and git

Never commit real tunnel state. `.gitignore` ignores:

- `tools/tunnel/config.yml` - your filled-in config (tunnel id, hostname, credentials path)
- `tools/tunnel/*.json` - tunnel credentials, if you keep them in this directory
- `tools/tunnel/cert.pem` - the Cloudflare login cert, if you keep it here

Only `config.example.yml`, `run.sh`, and this README are tracked.

## Live end-to-end verification

Verifying the full path (watch -> phone -> Cloudflare -> daemon) needs your Cloudflare account and the physical device, so it is **manual** and belongs to the integration issue **I1**, not here.
Quick local sanity check once the tunnel is up:

```
curl -s -H "Authorization: Bearer $CLAUDEWATCH_TOKEN" \
  "https://<your-hostname>/sessions?limit=10" | jq .
```
