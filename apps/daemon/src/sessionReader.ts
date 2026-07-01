/**
 * Session reader: turns `~/.claude/projects/<project>/<uuid>.jsonl` history
 * files into the frozen /sessions contract model.
 *
 * Pipeline: enumerate project dirs -> drop excluded dirs -> parse each `.jsonl`
 * -> drop degenerate sessions -> sort newest-first -> truncate to `limit`.
 */
import { readdirSync, readFileSync, statSync } from "node:fs";
import { basename, join } from "node:path";
import {
  ACTIVE_WINDOW_SECONDS,
  DEFAULT_LIMIT,
  MAX_LIMIT,
  PENDING_USER_WINDOW_SECONDS,
  WAITING_WINDOW_SECONDS,
  WORKING_WINDOW_SECONDS,
  resolveProjectsDir,
  resolveStateDir,
} from "./config.js";
import { readHookState } from "./stateStore.js";
import type { Session, SessionState } from "./types.js";

const TITLE_MAX = 60;

export interface ReadSessionsOptions {
  /** Root projects directory. Defaults to the resolved CLAUDE_PROJECTS_DIR. */
  projectsDir?: string;
  /** Max sessions to return. Defaults to 10, hard-capped at 50. */
  limit?: number;
  /** Injectable clock (ms) for deterministic `active`/`state` computation. */
  now?: number;
  /** Directory of hook-written state files. Defaults to resolveStateDir(). */
  stateDir?: string;
}

/** Project directories we never surface (worktree scratch dirs, config store). */
function isExcludedProjectDir(name: string): boolean {
  return name.includes("-worktrees-") || name.endsWith("--config");
}

/** One decoded JSONL line; only the fields we care about are typed. */
interface Line {
  type?: string;
  cwd?: string;
  aiTitle?: string;
  lastPrompt?: string;
}

interface ParsedSession {
  hasUser: boolean;
  cwd: string | undefined;
  aiTitle: string | undefined;
  lastPrompt: string | undefined;
  messages: number;
  /** Type of the last real conversation turn (metadata lines ignored). */
  lastTurn: "user" | "assistant" | undefined;
}

/** Parse a single session file, accumulating only the fields the model needs. */
function parseSessionFile(filePath: string): ParsedSession {
  const acc: ParsedSession = {
    hasUser: false,
    cwd: undefined,
    aiTitle: undefined,
    lastPrompt: undefined,
    messages: 0,
    lastTurn: undefined,
  };

  const raw = readFileSync(filePath, "utf8");
  for (const rawLine of raw.split("\n")) {
    const line = rawLine.trim();
    if (line.length === 0) continue;

    let entry: Line;
    try {
      entry = JSON.parse(line) as Line;
    } catch {
      continue; // tolerate a partially-written trailing line
    }

    switch (entry.type) {
      case "user":
        acc.hasUser = true;
        acc.messages += 1;
        acc.lastTurn = "user";
        break;
      case "assistant":
        acc.messages += 1;
        acc.lastTurn = "assistant";
        break;
      case "ai-title":
        // Keep the last one seen.
        if (typeof entry.aiTitle === "string") acc.aiTitle = entry.aiTitle;
        break;
      case "last-prompt":
        if (typeof entry.lastPrompt === "string") acc.lastPrompt = entry.lastPrompt;
        break;
      default:
        break;
    }

    // `cwd` may ride on any line; first non-empty wins and is stable.
    if (acc.cwd === undefined && typeof entry.cwd === "string" && entry.cwd.length > 0) {
      acc.cwd = entry.cwd;
    }
  }

  return acc;
}

/**
 * Title fallback chain (contract): last aiTitle -> lastPrompt truncated to 60
 * chars -> "Untitled". Returns "" only if every candidate is blank, which the
 * "Untitled" fallback prevents in practice.
 */
function resolveTitle(parsed: ParsedSession): string {
  const ai = parsed.aiTitle?.trim();
  if (ai) return ai;

  const prompt = parsed.lastPrompt?.trim();
  if (prompt) return prompt.slice(0, TITLE_MAX);

  return "Untitled";
}

/**
 * Heuristic activity state from file freshness + the last conversation turn:
 * - touched very recently -> "working" (the file is actively being appended)
 * - user spoke last & recently -> "working" (input pending, Claude presumably running)
 * - assistant spoke last & recently -> "waiting" (Claude answered; your move)
 * - otherwise -> "idle"
 *
 * This is the fallback; a fresh hook state (stateStore) overrides it.
 */
function heuristicState(
  ageSeconds: number,
  lastTurn: "user" | "assistant" | undefined,
): SessionState {
  if (ageSeconds <= WORKING_WINDOW_SECONDS) return "working";
  if (lastTurn === "user" && ageSeconds <= PENDING_USER_WINDOW_SECONDS) return "working";
  if (lastTurn === "assistant" && ageSeconds <= WAITING_WINDOW_SECONDS) return "waiting";
  return "idle";
}

/** Shorten the filename stem to a short id, keeping it unique within the run. */
function shortId(stem: string, used: Set<string>): string {
  const short = stem.slice(0, 8);
  const id = used.has(short) ? stem : short;
  used.add(id);
  return id;
}

function clampLimit(limit: number | undefined): number {
  if (limit === undefined || !Number.isFinite(limit)) return DEFAULT_LIMIT;
  return Math.max(0, Math.min(Math.floor(limit), MAX_LIMIT));
}

/**
 * Read and rank sessions from the projects directory.
 * Missing directories yield an empty list rather than throwing.
 */
export function readSessions(options: ReadSessionsOptions = {}): Session[] {
  const projectsDir = options.projectsDir ?? resolveProjectsDir();
  const stateDir = options.stateDir ?? resolveStateDir();
  const limit = clampLimit(options.limit);
  const nowSeconds = Math.floor((options.now ?? Date.now()) / 1000);

  let projectDirs: string[];
  try {
    projectDirs = readdirSync(projectsDir, { withFileTypes: true })
      .filter((d) => d.isDirectory() && !isExcludedProjectDir(d.name))
      .map((d) => d.name);
  } catch {
    return [];
  }

  const usedIds = new Set<string>();
  const sessions: Session[] = [];

  for (const dir of projectDirs) {
    const dirPath = join(projectsDir, dir);
    let files: string[];
    try {
      files = readdirSync(dirPath).filter((f) => f.endsWith(".jsonl"));
    } catch {
      continue;
    }

    for (const file of files) {
      const filePath = join(dirPath, file);
      let mtimeMs: number;
      try {
        mtimeMs = statSync(filePath).mtimeMs;
      } catch {
        continue;
      }

      const parsed = parseSessionFile(filePath);
      const title = resolveTitle(parsed);

      // Degenerate sessions: no user turn, or no title could be derived.
      if (!parsed.hasUser || title.length === 0) continue;

      const lastActive = Math.floor(mtimeMs / 1000);
      const fullId = file.replace(/\.jsonl$/, "");
      const ageSeconds = nowSeconds - lastActive;
      // Hybrid: a fresh hook-written state wins; otherwise fall back to the
      // freshness + last-turn heuristic.
      const state =
        readHookState(fullId, nowSeconds, stateDir) ??
        heuristicState(ageSeconds, parsed.lastTurn);

      sessions.push({
        id: shortId(fullId, usedIds),
        project: parsed.cwd ? basename(parsed.cwd) : dir,
        title,
        lastActive,
        messages: parsed.messages,
        active: ageSeconds <= ACTIVE_WINDOW_SECONDS && nowSeconds >= lastActive,
        state,
      });
    }
  }

  sessions.sort((a, b) => b.lastActive - a.lastActive);
  return sessions.slice(0, limit);
}
