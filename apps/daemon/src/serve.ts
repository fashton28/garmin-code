#!/usr/bin/env tsx
/**
 * `npm run serve` - boot the ClaudeWatch HTTP daemon (issue B2).
 *
 * On startup, loads apps/daemon/.env (if present) via a tiny zero-dependency
 * loader so PORT, CLAUDEWATCH_TOKEN, and CLAUDE_PROJECTS_DIR can live in a file
 * (see apps/daemon/.env.example). The real environment always wins over the
 * file, and a missing file is fine - CI and the B3 tunnel pass the token via
 * the environment. Serves the frozen `/sessions` contract.
 *
 * Manual verification once running (default PORT 8787):
 *
 *   curl -s -H "Authorization: Bearer $CLAUDEWATCH_TOKEN" \
 *     "http://localhost:8787/sessions?limit=10" | jq .
 *
 *   # missing/wrong token -> HTTP 401, empty body:
 *   curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8787/sessions
 */
import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { serve } from "@hono/node-server";
import { createApp } from "./server.js";
import { resolvePort, resolveProjectsDir, resolveToken } from "./config.js";

/**
 * Load KEY=VALUE pairs from the daemon's .env (the package root, next to
 * .env.example) into process.env, without adding a dependency. Existing
 * environment variables are never overwritten, so the real environment wins
 * over the file. A missing file is a no-op. Works on any Node 20.x (unlike
 * node's --env-file-if-exists, which needs >=20.18).
 */
function loadDotEnv(): void {
  // serve.ts lives in apps/daemon/src, so the package root (and .env) is one up.
  const envPath = resolve(dirname(fileURLToPath(import.meta.url)), "..", ".env");
  let contents: string;
  try {
    contents = readFileSync(envPath, "utf8");
  } catch {
    return;
  }
  for (const rawLine of contents.split(/\r?\n/)) {
    const line = rawLine.trim();
    if (line === "" || line.startsWith("#")) continue;
    const eq = line.indexOf("=");
    if (eq === -1) continue;
    const key = line.slice(0, eq).trim();
    if (key === "") continue;
    let value = line.slice(eq + 1).trim();
    if (
      value.length >= 2 &&
      (value[0] === '"' || value[0] === "'") &&
      value[value.length - 1] === value[0]
    ) {
      value = value.slice(1, -1);
    }
    if (process.env[key] === undefined) process.env[key] = value;
  }
}

function main(): void {
  loadDotEnv();


  const token = resolveToken();
  if (token === undefined) {
    process.stderr.write(
      "Refusing to start: CLAUDEWATCH_TOKEN is not set. " +
        "Copy apps/daemon/.env.example to apps/daemon/.env and set a token " +
        "(e.g. openssl rand -hex 32).\n",
    );
    process.exit(1);
  }

  const port = resolvePort();
  const projectsDir = resolveProjectsDir();
  const app = createApp({ token, projectsDir });

  serve({ fetch: app.fetch, port }, (info) => {
    process.stdout.write(
      `ClaudeWatch daemon listening on http://localhost:${info.port}/sessions\n`,
    );
  });
}

main();
