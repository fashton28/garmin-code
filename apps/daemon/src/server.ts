/**
 * HTTP surface for issue B2: the `GET /sessions` endpoint from the frozen
 * contract, guarded by a bearer token.
 *
 * Design:
 * - Routing is a single Hono route. `createApp()` returns the app so tests can
 *   drive it in-process via `app.request(...)` with no real port/network.
 * - Auth is a constant-time bearer comparison (see {@link tokensMatch}).
 * - The body is produced by B1's `readSessions()` and re-checked with B1's
 *   `validateResponse()` so the API can never emit off-contract data.
 */
import { createHash, timingSafeEqual } from "node:crypto";
import { Hono } from "hono";
import { DEFAULT_LIMIT } from "./config.js";
import { readSessions } from "./sessionReader.js";
import { validateResponse } from "./schema.js";
import { getTask, startTask } from "./taskRunner.js";
import { isTaskType } from "./tasks.js";
import { readUsage } from "./usageReader.js";
import type { SessionsResponse } from "./types.js";

export interface AppOptions {
  /**
   * Shared secret the client must present as `Authorization: Bearer <token>`.
   * When `undefined` (unconfigured), every request is rejected with 401.
   */
  token: string | undefined;
  /** Root projects directory passed through to the reader. Defaults to env. */
  projectsDir?: string;
  /** Override the `claude` binary the task runner spawns (tests inject a fake). */
  claudeBin?: string;
}

/**
 * Constant-time bearer token comparison.
 *
 * A naive `a === b` string compare short-circuits on the first differing byte,
 * leaking how many leading characters an attacker guessed correctly via timing.
 * `timingSafeEqual` always compares the full buffers. It requires equal-length
 * inputs, so we hash both sides to a fixed 32-byte digest first: this keeps the
 * comparison constant-time regardless of the candidate's length and avoids
 * leaking the real token's length. An unset server token never matches.
 */
function tokensMatch(expected: string | undefined, candidate: string): boolean {
  if (expected === undefined) return false;
  const a = createHash("sha256").update(expected).digest();
  const b = createHash("sha256").update(candidate).digest();
  return timingSafeEqual(a, b);
}

/** Extract the token from an `Authorization: Bearer <token>` header. */
function extractBearer(header: string | undefined): string | undefined {
  if (!header) return undefined;
  const match = /^Bearer (.+)$/i.exec(header);
  return match?.[1];
}

/**
 * Parse the `?limit=` query param. Missing or non-numeric input yields the
 * contract default (10); the reader clamps the upper bound to 50.
 */
function parseLimit(raw: string | undefined): number {
  if (raw === undefined) return DEFAULT_LIMIT;
  const value = Number(raw);
  if (!Number.isFinite(value)) return DEFAULT_LIMIT;
  return value;
}

/** True if the request carries the correct bearer token. */
function isAuthed(authHeader: string | undefined, token: string | undefined): boolean {
  const candidate = extractBearer(authHeader);
  return candidate !== undefined && tokensMatch(token, candidate);
}

/** Build the ClaudeWatch HTTP app. Pure factory - no side effects, no listen. */
export function createApp(options: AppOptions): Hono {
  const app = new Hono();

  app.get("/sessions", (c) => {
    // 401 on missing or wrong token, with no body so we leak nothing.
    if (!isAuthed(c.req.header("Authorization"), options.token)) return c.body(null, 401);

    const limit = parseLimit(c.req.query("limit"));
    const response: SessionsResponse = {
      sessions: readSessions({ projectsDir: options.projectsDir, limit }),
    };
    // Fail loudly (500) rather than ever emit an off-contract body.
    validateResponse(response);
    return c.json(response, 200);
  });

  // Overall usage across all sessions for the watch dashboard.
  app.get("/usage", (c) => {
    if (!isAuthed(c.req.header("Authorization"), options.token)) return c.body(null, 401);
    return c.json(readUsage(options.projectsDir), 200);
  });

  // Start a task in a session (create_pr | run_tests | review). Returns a task
  // id to poll. The task runs `claude -p` headlessly in the session's cwd.
  app.post("/sessions/:id/tasks", async (c) => {
    if (!isAuthed(c.req.header("Authorization"), options.token)) return c.body(null, 401);

    let body: unknown;
    try {
      body = await c.req.json();
    } catch {
      body = undefined;
    }
    const taskType = (body as { task?: unknown } | undefined)?.task;
    if (!isTaskType(taskType)) return c.json({ error: "unknown_task" }, 400);

    const result = startTask(c.req.param("id"), taskType, {
      projectsDir: options.projectsDir,
      claudeBin: options.claudeBin,
    });
    if (!result.ok) {
      return c.json({ error: result.error }, result.error === "unknown_session" ? 404 : 400);
    }
    return c.json({ taskId: result.task.id, status: result.task.status }, 202);
  });

  // Poll a task's status: running -> done | failed, with a short summary.
  app.get("/tasks/:id", (c) => {
    if (!isAuthed(c.req.header("Authorization"), options.token)) return c.body(null, 401);

    const task = getTask(c.req.param("id"));
    if (task === undefined) return c.json({ error: "unknown_task_id" }, 404);
    return c.json(
      {
        id: task.id,
        sessionId: task.sessionId,
        type: task.type,
        status: task.status,
        summary: task.summary,
        model: task.model,
      },
      200,
    );
  });

  return app;
}
