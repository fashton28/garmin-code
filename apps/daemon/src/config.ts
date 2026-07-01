/** Configuration resolved from environment, with contract defaults. */
import { homedir } from "node:os";
import { join, resolve } from "node:path";

/** Default limit when the caller does not specify one. */
export const DEFAULT_LIMIT = 10;
/** Hard server-side cap on the number of sessions returned. */
export const MAX_LIMIT = 50;
/** A session is "active" if its mtime is within this many seconds of now. */
export const ACTIVE_WINDOW_SECONDS = 60;

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
