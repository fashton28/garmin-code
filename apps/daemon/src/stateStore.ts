/**
 * Reads per-session state files written by the optional ClaudeWatch hooks
 * (see tools/hooks/). Each file is `<stateDir>/<full-session-id>.json` holding
 * `{ "state": "working"|"waiting"|"idle", "ts": <unix seconds> }`.
 *
 * This is the accurate half of the hybrid model: when a fresh hook state exists
 * it overrides the mtime heuristic in sessionReader. Absent, malformed, or
 * stale files return null so the caller falls back to the heuristic.
 */
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { HOOK_FRESH_SECONDS, resolveStateDir } from "./config.js";
import type { SessionState } from "./types.js";

const VALID_STATES: readonly SessionState[] = ["working", "waiting", "idle"];

/**
 * Return the hook-reported state for a session, or null if there is no usable,
 * fresh hook state. `fullId` is the session filename stem (the full UUID).
 */
export function readHookState(
  fullId: string,
  nowSeconds: number,
  stateDir: string = resolveStateDir(),
): SessionState | null {
  let raw: string;
  try {
    raw = readFileSync(join(stateDir, `${fullId}.json`), "utf8");
  } catch {
    return null; // no hook state for this session
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    return null;
  }
  if (typeof parsed !== "object" || parsed === null) return null;

  const { state, ts } = parsed as Record<string, unknown>;
  if (typeof state !== "string" || !VALID_STATES.includes(state as SessionState)) return null;
  if (typeof ts !== "number") return null;
  // Ignore states that are too old (e.g. a "working" session that was abandoned).
  if (nowSeconds - ts > HOOK_FRESH_SECONDS) return null;

  return state as SessionState;
}
