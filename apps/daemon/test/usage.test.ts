import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { after, before, describe, test } from "node:test";
import { readUsage } from "../src/usageReader.js";

let projects: string;

function assistant(model: string, input: number, output: number, cacheRead = 0): string {
  return JSON.stringify({
    type: "assistant",
    message: { model, usage: { input_tokens: input, output_tokens: output, cache_read_input_tokens: cacheRead } },
  });
}

before(() => {
  projects = mkdtempSync(join(tmpdir(), "cw-usage-"));
  mkdirSync(join(projects, "-Users-a"), { recursive: true });
  mkdirSync(join(projects, "-Users-b"), { recursive: true });
  mkdirSync(join(projects, "-Users-x--worktrees-abc"), { recursive: true });

  writeFileSync(
    join(projects, "-Users-a", "s1.jsonl"),
    [
      JSON.stringify({ type: "user", message: { content: "hi" } }),
      assistant("claude-opus-4-8", 100, 900, 5000),
      assistant("<synthetic>", 0, 0),
    ].join("\n") + "\n",
  );
  writeFileSync(
    join(projects, "-Users-b", "s2.jsonl"),
    [assistant("claude-fable-5", 50, 100, 1000)].join("\n") + "\n",
  );
  // Excluded dir must not be counted.
  writeFileSync(join(projects, "-Users-x--worktrees-abc", "s3.jsonl"), assistant("claude-fable-5", 999, 999) + "\n");
});
after(() => rmSync(projects, { recursive: true, force: true }));

describe("readUsage", () => {
  test("aggregates tokens, counts, and excludes worktree dirs", () => {
    const u = readUsage(projects);
    assert.equal(u.sessions, 2); // s1, s2 (worktree excluded)
    assert.equal(u.messages, 3); // 2 real + 1 synthetic assistant lines
    assert.equal(u.inputTokens, 150);
    assert.equal(u.outputTokens, 1000);
    assert.equal(u.cacheReadTokens, 6000);
  });

  test("breaks down output tokens by model, top-first, shortened", () => {
    const u = readUsage(projects);
    assert.deepEqual(
      u.models.map((m) => m.name),
      ["opus-4-8", "fable-5"],
    );
    assert.equal(u.models[0]!.outputTokens, 900);
  });
});
