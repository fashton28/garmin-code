/** Configuration resolved from environment, with contract defaults. */
import { homedir } from "node:os";
import { join, resolve } from "node:path";

/** Default limit when the caller does not specify one. */
export const DEFAULT_LIMIT = 10;
/** Hard server-side cap on the number of sessions returned. */
export const MAX_LIMIT = 50;
/** A session is "active" if its mtime is within this many seconds of now. */
export const ACTIVE_WINDOW_SECONDS = 60;
/** Default port the HTTP server listens on when PORT is unset. */
export const DEFAULT_PORT = 8787;

// --- Heuristic state thresholds (see sessionReader.deriveState) ---
/** File touched within this many seconds -> "working" (actively appending). */
export const WORKING_WINDOW_SECONDS = 30;
/** Last turn was the user, within this window -> "working" (input pending). */
export const PENDING_USER_WINDOW_SECONDS = 300;
/** Last turn was the assistant, within this window -> "waiting" (your move). */
export const WAITING_WINDOW_SECONDS = 600;
/** A hook-written state older than this is stale (session likely abandoned). */
export const HOOK_FRESH_SECONDS = 6 * 60 * 60;

/**
 * Resolve the directory where Claude Code hooks drop per-session state files.
 * Honors CLAUDEWATCH_STATE_DIR, defaulting to `~/.claude/claudewatch-state`.
 */
export function resolveStateDir(env: NodeJS.ProcessEnv = process.env): string {
  return expandHome(env.CLAUDEWATCH_STATE_DIR ?? join(homedir(), ".claude", "claudewatch-state"));
}

/** Shorten a model id for display: "claude-fable-5" -> "fable-5". */
export function shortModelName(id: string): string {
  return id.replace(/^claude-/, "").replace(/-\d{8}$/, "");
}

/** Expand a leading `~` to the user's home directory, then resolve to absolute. */
export function expandHome(p: string): string {
  if (p === "~") return homedir();
  if (p.startsWith("~/")) return join(homedir(), p.slice(2));
  return resolve(p);
}

/**
 * Resolve the Claude Code projects directory.
 * Honors CLAUDE_PROJECTS_DIR, defaulting to `~/.claude/projects`.
 */
export function resolveProjectsDir(env: NodeJS.ProcessEnv = process.env): string {
  return expandHome(env.CLAUDE_PROJECTS_DIR ?? join(homedir(), ".claude", "projects"));
}

/**
 * Resolve the HTTP listen port from PORT, falling back to {@link DEFAULT_PORT}.
 * A non-numeric or out-of-range PORT falls back to the default.
 */
export function resolvePort(env: NodeJS.ProcessEnv = process.env): number {
  const raw = env.PORT;
  if (raw === undefined || raw.trim() === "") return DEFAULT_PORT;
  const port = Number(raw);
  if (!Number.isInteger(port) || port < 1 || port > 65535) return DEFAULT_PORT;
  return port;
}

/**
 * Resolve the shared bearer token from CLAUDEWATCH_TOKEN.
 * Returns `undefined` when unset/blank so callers can fail fast at boot; the
 * server itself treats an unset token as "reject every request".
 */
export function resolveToken(env: NodeJS.ProcessEnv = process.env): string | undefined {
  const raw = env.CLAUDEWATCH_TOKEN;
  if (raw === undefined || raw.trim() === "") return undefined;
  return raw;
}
