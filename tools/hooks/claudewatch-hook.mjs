#!/usr/bin/env node
// ClaudeWatch state hook. Configured on Claude Code lifecycle events, it writes
// the session's current state so the daemon can report it accurately (the
// "hook" half of the hybrid model - see docs/session-state.md).
//
// Usage (from a hook `command`): node claudewatch-hook.mjs <working|waiting|idle>
// Reads the hook payload (JSON) on stdin, pulls session_id, and writes
//   <CLAUDEWATCH_STATE_DIR|~/.claude/claudewatch-state>/<session_id>.json
//   = { "state": <state>, "ts": <unix seconds> }
//
// Fails open: any bad input / write error exits 0 so it never blocks Claude.
import { mkdirSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const state = process.argv[2];
if (state !== "working" && state !== "waiting" && state !== "idle") {
  process.exit(0); // nothing to record for an unrecognized state
}

let input = "";
try {
  process.stdin.setEncoding("utf8");
  for await (const chunk of process.stdin) input += chunk;
} catch {
  process.exit(0);
}

let sessionId;
try {
  sessionId = JSON.parse(input).session_id;
} catch {
  process.exit(0);
}
if (typeof sessionId !== "string" || sessionId.length === 0) {
  process.exit(0);
}

const dir = process.env.CLAUDEWATCH_STATE_DIR ?? join(homedir(), ".claude", "claudewatch-state");
try {
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, `${sessionId}.json`), JSON.stringify({ state, ts: Math.floor(Date.now() / 1000) }));
} catch {
  // ignore - never block Claude on a state write
}
process.exit(0);
