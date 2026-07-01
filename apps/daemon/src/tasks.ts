/**
 * The fixed set of tasks the watch can trigger in a session. The watch sends
 * only these ids; each maps to a headless `claude -p` prompt plus a scoped
 * `--allowedTools` allowlist so a watch-triggered agent can't do more than the
 * task needs. See taskRunner.ts.
 */
export type TaskType = "create_pr" | "run_tests" | "review";

export interface TaskDef {
  /** Human label (kept in sync with the watch's task menu). */
  label: string;
  /** The instruction handed to `claude -p`. */
  prompt: string;
  /** `--allowedTools` entries; tight per task to limit blast radius. */
  allowedTools: string[];
}

export const TASKS: Record<TaskType, TaskDef> = {
  create_pr: {
    label: "Create PR",
    prompt:
      "Commit the current uncommitted changes onto a new feature branch, push it, " +
      "and open a pull request using the gh CLI. Your final reply MUST be one short " +
      "line reporting how it went: the pull request URL on success, or a brief " +
      "reason if there was nothing to commit or it failed.",
    allowedTools: ["Bash(git:*)", "Bash(gh:*)", "Read", "Grep", "Glob"],
  },
  run_tests: {
    label: "Run tests",
    prompt:
      "Run this project's test suite (detect the right command from the repo, e.g. " +
      "npm test). Your final reply MUST be ONE short line reporting how it went: " +
      "whether tests passed or failed, with the pass/fail counts.",
    allowedTools: [
      "Bash(npm:*)",
      "Bash(npx:*)",
      "Bash(node:*)",
      "Bash(pnpm:*)",
      "Bash(yarn:*)",
      "Bash(pytest:*)",
      "Bash(python:*)",
      "Bash(cargo:*)",
      "Bash(go:*)",
      "Bash(make:*)",
      "Read",
      "Grep",
      "Glob",
    ],
  },
  review: {
    label: "Review code",
    prompt:
      "Review the current uncommitted changes (git diff) and the most recent commits " +
      "for bugs, risks, and issues. Your final reply MUST be a concise summary " +
      "(1-3 short sentences) reporting how it went: the most important findings, or " +
      "that it looks good.",
    allowedTools: [
      "Bash(git diff:*)",
      "Bash(git log:*)",
      "Bash(git status:*)",
      "Bash(git show:*)",
      "Read",
      "Grep",
      "Glob",
    ],
  },
};

export function isTaskType(value: unknown): value is TaskType {
  return value === "create_pr" || value === "run_tests" || value === "review";
}
