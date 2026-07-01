#!/usr/bin/env tsx
/**
 * `npm run serve` - boot the ClaudeWatch HTTP daemon (issue B2).
 *
 * Reads PORT, CLAUDEWATCH_TOKEN, and CLAUDE_PROJECTS_DIR from the environment
 * (see apps/daemon/.env.example) and serves the frozen `/sessions` contract.
 *
 * Manual verification once running (default PORT 8787):
 *
 *   curl -s -H "Authorization: Bearer $CLAUDEWATCH_TOKEN" \
 *     "http://localhost:8787/sessions?limit=10" | jq .
 *
 *   # missing/wrong token -> HTTP 401, empty body:
 *   curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8787/sessions
 */
import { serve } from "@hono/node-server";
import { createApp } from "./server.js";
import { resolvePort, resolveProjectsDir, resolveToken } from "./config.js";

function main(): void {
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
