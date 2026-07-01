import assert from "node:assert/strict";
import { mkdtempSync, utimesSync, writeFileSync, mkdirSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { after, before, describe, test } from "node:test";
import { readSessions } from "../src/sessionReader.js";
import { validateResponse, ResponseValidationError } from "../src/schema.js";

const here = dirname(fileURLToPath(import.meta.url));
const FIXTURES = join(here, "fixtures");

// A fixed reference clock so `active`/sort assertions are deterministic.
const NOW = 1_782_903_600_000; // ms
const NOW_S = Math.floor(NOW / 1000);

/** Set a fixture file's mtime to `secondsAgo` before NOW. */
function setMtime(relPath: string, secondsAgo: number): void {
  const when = new Date(NOW - secondsAgo * 1000);
  utimesSync(join(FIXTURES, relPath), when, when);
}

before(() => {
  // sonar is the freshest (inside the 60s active window); the rest are older.
  setMtime("-Users-test-sonar/b0cf8046-1111-2222-3333-444455556666.jsonl", 10);
  setMtime("-Users-test-mux/7a1e9c33-aaaa-bbbb-cccc-ddddeeeeffff.jsonl", 3600);
  setMtime("-Users-test-untitled-proj/9d4a1f6b-0000-1111-2222-333344445555.jsonl", 7200);
});

describe("readSessions over synthetic fixtures", () => {
  const opts = { projectsDir: FIXTURES, now: NOW } as const;

  test("excludes -worktrees- and --config project dirs", () => {
    const projects = readSessions(opts).map((s) => s.project);
    assert.ok(!projects.includes("worktree-scratch"), "worktrees dir must be excluded");
    assert.ok(!projects.includes("thing"), "--config dir must be excluded");
  });

  test("skips degenerate sessions with no user message", () => {
    const ids = readSessions(opts).map((s) => s.id);
    assert.ok(!ids.includes("deadbeef"), "session with no user message must be skipped");
  });

  test("keeps exactly the three valid sessions", () => {
    assert.equal(readSessions(opts).length, 3);
  });

  test("aiTitle wins the title fallback chain", () => {
    const sonar = readSessions(opts).find((s) => s.project === "sonar");
    assert.ok(sonar);
    assert.equal(sonar.title, "Review entire repository for context");
  });

  test("falls back to lastPrompt truncated to 60 chars", () => {
    const mux = readSessions(opts).find((s) => s.project === "mux");
    assert.ok(mux);
    assert.equal(mux.title.length, 60);
    const fullPrompt =
      "This is a very long prompt that definitely exceeds sixty characters in total length so it must be truncated";
    assert.ok(fullPrompt.startsWith(mux.title));
  });

  test("falls back to \"Untitled\" when no title source exists", () => {
    const untitled = readSessions(opts).find((s) => s.project === "untitled-proj");
    assert.ok(untitled);
    assert.equal(untitled.title, "Untitled");
  });

  test("counts only user + assistant messages", () => {
    const sonar = readSessions(opts).find((s) => s.project === "sonar");
    assert.ok(sonar);
    assert.equal(sonar.messages, 5); // 3 user + 2 assistant; title/prompt lines ignored
  });

  test("derives project from cwd basename and id from filename stem", () => {
    const sonar = readSessions(opts).find((s) => s.project === "sonar");
    assert.ok(sonar);
    assert.equal(sonar.id, "b0cf8046");
  });

  test("sorts by lastActive descending (newest first)", () => {
    const sessions = readSessions(opts);
    const order = sessions.map((s) => s.project);
    assert.deepEqual(order, ["sonar", "mux", "untitled-proj"]);
    for (let i = 1; i < sessions.length; i++) {
      assert.ok(sessions[i - 1]!.lastActive >= sessions[i]!.lastActive);
    }
  });

  test("marks recent sessions active and old ones inactive", () => {
    const sessions = readSessions(opts);
    assert.equal(sessions.find((s) => s.project === "sonar")!.active, true);
    assert.equal(sessions.find((s) => s.project === "mux")!.active, false);
    assert.equal(sessions.find((s) => s.project === "sonar")!.lastActive, NOW_S - 10);
  });

  test("output validates against the ajv schema", () => {
    const response = { sessions: readSessions(opts) };
    assert.doesNotThrow(() => validateResponse(response));
  });
});

describe("limit handling", () => {
  let scratch: string;

  before(() => {
    scratch = mkdtempSync(join(tmpdir(), "cw-limit-"));
    const proj = join(scratch, "-Users-test-many");
    mkdirSync(proj);
    for (let i = 0; i < 60; i++) {
      const id = `sess${String(i).padStart(4, "0")}`;
      writeFileSync(
        join(proj, `${id}.jsonl`),
        `{"type":"user","cwd":"/Users/test/many","message":"hi"}\n` +
          `{"type":"assistant","message":"yo"}\n`,
      );
    }
  });

  after(() => rmSync(scratch, { recursive: true, force: true }));

  test("caps at 50 even when limit exceeds the hard cap", () => {
    assert.equal(readSessions({ projectsDir: scratch, limit: 999 }).length, 50);
  });

  test("defaults to 10 when no limit is given", () => {
    assert.equal(readSessions({ projectsDir: scratch }).length, 10);
  });

  test("honors an explicit limit below the cap", () => {
    assert.equal(readSessions({ projectsDir: scratch, limit: 3 }).length, 3);
  });
});

describe("schema validator", () => {
  test("rejects an unknown extra field", () => {
    const bad = { sessions: [{ id: "x", project: "p", title: "t", lastActive: 1, messages: 0, active: false, extra: 1 }] };
    assert.throws(() => validateResponse(bad), ResponseValidationError);
  });

  test("rejects a non-descending sort order", () => {
    const bad = {
      sessions: [
        { id: "a", project: "p", title: "t", lastActive: 1, messages: 0, active: false },
        { id: "b", project: "p", title: "t", lastActive: 5, messages: 0, active: false },
      ],
    };
    assert.throws(() => validateResponse(bad), ResponseValidationError);
  });

  test("accepts the canonical shape", () => {
    const ok = { sessions: [{ id: "a", project: "p", title: "t", lastActive: 5, messages: 3, active: true }] };
    assert.doesNotThrow(() => validateResponse(ok));
  });
});
