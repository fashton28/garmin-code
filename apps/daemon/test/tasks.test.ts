import assert from "node:assert/strict";
import { chmodSync, mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { createApp } from "../src/server.js";

// The JSON a successful `claude -p --output-format json` prints (trimmed).
const SUCCESS_JSON =
  '{"type":"result","subtype":"success","is_error":false,"result":"https://github.com/o/r/pull/42 opened",' +
  '"modelUsage":{"claude-haiku-4-5-20251001":{"outputTokens":11},"claude-fable-5":{"outputTokens":900}}}';

let root: string;
let projects: string;
let okClaude: string;
let failClaude: string;
const SID = "abcd1234-1111-2222-3333-444455556666";
const AUTH = { Authorization: "Bearer t" };

before(() => {
  root = mkdtempSync(join(tmpdir(), "cw-tasks-"));
  projects = join(root, "projects");
  mkdirSync(join(projects, "-Users-test-proj"), { recursive: true });
  writeFileSync(
    join(projects, "-Users-test-proj", `${SID}.jsonl`),
    `${JSON.stringify({ type: "user", cwd: root, message: { role: "user", content: "hi" } })}\n`,
  );

  okClaude = join(root, "ok-claude.sh");
  writeFileSync(okClaude, `#!/usr/bin/env bash\necho '${SUCCESS_JSON}'\n`);
  chmodSync(okClaude, 0o755);

  failClaude = join(root, "fail-claude.sh");
  writeFileSync(failClaude, "#!/usr/bin/env bash\necho boom >&2\nexit 1\n");
  chmodSync(failClaude, 0o755);
});
after(() => rmSync(root, { recursive: true, force: true }));

function app(claudeBin: string = okClaude) {
  return createApp({ token: "t", projectsDir: projects, claudeBin });
}

function post(a: ReturnType<typeof app>, id: string, task: unknown, headers: Record<string, string> = AUTH) {
  return a.request(`/sessions/${id}/tasks`, {
    method: "POST",
    headers: { ...headers, "Content-Type": "application/json" },
    body: JSON.stringify({ task }),
  });
}

async function waitSettled(
  a: ReturnType<typeof app>,
  taskId: string,
): Promise<{ status: string; summary: string; model: string }> {
  for (let i = 0; i < 100; i++) {
    const res = await a.request(`/tasks/${taskId}`, { headers: AUTH });
    const body = (await res.json()) as { status: string; summary: string; model: string };
    if (body.status !== "running") return body;
    await new Promise((r) => setTimeout(r, 20));
  }
  throw new Error("task did not settle");
}

describe("task endpoints", () => {
  test("401 without a token", async () => {
    const res = await post(app(), "abcd1234", "review", {});
    assert.equal(res.status, 401);
  });

  test("400 on an unknown task type", async () => {
    const res = await post(app(), "abcd1234", "delete_everything");
    assert.equal(res.status, 400);
  });

  test("404 on an unknown session", async () => {
    const res = await post(app(), "zzzz9999", "review");
    assert.equal(res.status, 404);
  });

  test("starts a task and reports done with a summary", async () => {
    const a = app();
    const start = await post(a, "abcd1234", "create_pr");
    assert.equal(start.status, 202);
    const { taskId } = (await start.json()) as { taskId: string };
    assert.ok(taskId);

    const settled = await waitSettled(a, taskId);
    assert.equal(settled.status, "done");
    assert.match(settled.summary, /pull\/42/); // create_pr extracts the PR URL
    assert.equal(settled.model, "fable-5"); // primary model, shortened
  });

  test("reports failed when claude errors", async () => {
    const a = app(failClaude);
    const start = await post(a, "abcd1234", "run_tests");
    const { taskId } = (await start.json()) as { taskId: string };
    const settled = await waitSettled(a, taskId);
    assert.equal(settled.status, "failed");
  });

  test("404 polling an unknown task id", async () => {
    const res = await app().request("/tasks/does-not-exist", { headers: AUTH });
    assert.equal(res.status, 404);
  });
});
