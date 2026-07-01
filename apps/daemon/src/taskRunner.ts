/**
 * Runs watch-triggered tasks by spawning `claude -p` headlessly in a session's
 * working directory, and tracks them in an in-memory registry the watch polls.
 *
 * Each task resumes a specific session (`--resume <uuid>`), runs a fixed prompt
 * with a scoped `--allowedTools` allowlist and `--permission-mode acceptEdits`
 * (so no interactive prompt can block it), and captures the JSON result.
 */
import { spawn } from "node:child_process";
import { randomUUID } from "node:crypto";
import { shortModelName } from "./config.js";
import { findSession } from "./sessionReader.js";
import { TASKS, type TaskType } from "./tasks.js";

export type TaskStatus = "running" | "done" | "failed";

export interface TaskRecord {
  id: string;
  /** Short session id the task was started for. */
  sessionId: string;
  type: TaskType;
  status: TaskStatus;
  /** Short human-readable result/summary (PR URL, test result, findings...). */
  summary: string;
  /** Primary model that ran the task (short name), or "" if unknown. */
  model: string;
  /** Unix seconds. */
  startedAt: number;
}

const TASK_TIMEOUT_MS = 5 * 60 * 1000;
const SUMMARY_MAX = 160;

const registry = new Map<string, TaskRecord>();

export function getTask(id: string): TaskRecord | undefined {
  return registry.get(id);
}

export interface StartTaskOptions {
  projectsDir?: string;
  /** Override the claude binary (tests inject a fake). */
  claudeBin?: string;
  /** Injectable clock (ms). */
  now?: number;
}

export type StartResult =
  | { ok: true; task: TaskRecord }
  | { ok: false; error: "unknown_task" | "unknown_session" };

/** Start a task for a session. Returns immediately; the child runs in the background. */
export function startTask(shortId: string, type: string, opts: StartTaskOptions = {}): StartResult {
  const def = (TASKS as Record<string, (typeof TASKS)[TaskType]>)[type];
  if (def === undefined) return { ok: false, error: "unknown_task" };

  const session = findSession(shortId, opts.projectsDir);
  if (session === null) return { ok: false, error: "unknown_session" };

  const task: TaskRecord = {
    id: randomUUID(),
    sessionId: shortId,
    type: type as TaskType,
    status: "running",
    summary: "",
    model: "",
    startedAt: Math.floor((opts.now ?? Date.now()) / 1000),
  };
  registry.set(task.id, task);

  const args = [
    "-p",
    def.prompt,
    "--resume",
    session.fullId,
    "--output-format",
    "json",
    "--permission-mode",
    "acceptEdits",
    "--allowedTools",
    ...def.allowedTools,
  ];

  const child = spawn(opts.claudeBin ?? "claude", args, {
    cwd: session.cwd,
    env: process.env,
  });

  let stdout = "";
  let stderr = "";
  child.stdout.on("data", (d: Buffer) => (stdout += d.toString()));
  child.stderr.on("data", (d: Buffer) => (stderr += d.toString()));

  const timer = setTimeout(() => child.kill("SIGTERM"), TASK_TIMEOUT_MS);

  child.on("error", (err: Error) => {
    clearTimeout(timer);
    task.status = "failed";
    task.summary = clip(`could not start claude: ${err.message}`);
  });

  child.on("close", (code: number | null) => {
    clearTimeout(timer);
    finish(task, code, stdout, stderr);
  });

  return { ok: true, task };
}

/** Interpret the `claude -p --output-format json` result. */
function finish(task: TaskRecord, code: number | null, stdout: string, stderr: string): void {
  let parsed: unknown;
  try {
    parsed = JSON.parse(stdout);
  } catch {
    task.status = "failed";
    task.summary = clip(stderr.trim() || `claude exited (${code ?? "killed"})`);
    return;
  }

  const obj = parsed as { is_error?: unknown; subtype?: unknown; result?: unknown; modelUsage?: unknown };
  task.model = primaryModel(obj.modelUsage);
  if (obj.is_error === false && obj.subtype === "success") {
    task.status = "done";
    task.summary = summarize(task.type, String(obj.result ?? ""));
  } else {
    task.status = "failed";
    task.summary = clip(String(obj.result ?? obj.subtype ?? "Task failed"));
  }
}

/** Pick the primary model (most output tokens) from the result's modelUsage. */
function primaryModel(modelUsage: unknown): string {
  if (typeof modelUsage !== "object" || modelUsage === null) return "";
  let best = "";
  let bestOut = -1;
  for (const [name, usage] of Object.entries(modelUsage as Record<string, unknown>)) {
    const out = (usage as { outputTokens?: unknown })?.outputTokens;
    if (typeof out === "number" && out > bestOut) {
      bestOut = out;
      best = name;
    }
  }
  return shortModelName(best);
}

/** Turn a result string into a short watch-friendly summary. */
function summarize(type: TaskType, result: string): string {
  if (type === "create_pr") {
    const url = result.match(/https?:\/\/\S+/);
    if (url) return clip(url[0]);
  }
  const oneLine = result.replace(/\s+/g, " ").trim();
  return clip(oneLine.length > 0 ? oneLine : "done");
}

function clip(s: string): string {
  return s.length > SUMMARY_MAX ? `${s.slice(0, SUMMARY_MAX - 1)}…` : s;
}
