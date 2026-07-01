import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";
import { mkdirSync, mkdtempSync, rmSync, utimesSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { after, before, describe, test } from "node:test";
import { createApp } from "../src/server.js";
import { validateResponse } from "../src/schema.js";

const here = dirname(fileURLToPath(import.meta.url));
const FIXTURES = join(here, "fixtures");
const TOKEN = "test-secret-token";

// Freshen fixture mtimes so the reader surfaces the three valid sessions,
// mirroring the setup in sessionReader.test.ts.
const NOW = 1_782_903_600_000; // ms
function setMtime(relPath: string, secondsAgo: number): void {
  const when = new Date(NOW - secondsAgo * 1000);
  utimesSync(join(FIXTURES, relPath), when, when);
}

before(() => {
  setMtime("-Users-test-sonar/b0cf8046-1111-2222-3333-444455556666.jsonl", 10);
  setMtime("-Users-test-mux/7a1e9c33-aaaa-bbbb-cccc-ddddeeeeffff.jsonl", 3600);
  setMtime("-Users-test-untitled-proj/9d4a1f6b-0000-1111-2222-333344445555.jsonl", 7200);
});

/** Build an app pointed at the synthetic B1 fixtures. */
function app() {
  return createApp({ token: TOKEN, projectsDir: FIXTURES });
}

function authed(path: string, token = TOKEN): Request {
  return new Request(`http://localhost${path}`, {
    headers: { Authorization: `Bearer ${token}` },
  });
}

describe("GET /sessions - auth", () => {
  test("200 with a contract-valid body for the correct token", async () => {
    const res = await app().request(authed("/sessions"));
    assert.equal(res.status, 200);
    // validateResponse both enforces the frozen contract and narrows the type.
    const body = validateResponse(await res.json());
    assert.equal(body.sessions.length, 3);
  });

  test("401 with no body when the token is missing", async () => {
    const res = await app().request(new Request("http://localhost/sessions"));
    assert.equal(res.status, 401);
    assert.equal(await res.text(), "");
  });

  test("401 with no body when the token is wrong", async () => {
    const res = await app().request(authed("/sessions", "not-the-token"));
    assert.equal(res.status, 401);
    assert.equal(await res.text(), "");
  });

  test("401 when the server has no token configured", async () => {
    const noToken = createApp({ token: undefined, projectsDir: FIXTURES });
    const res = await noToken.request(authed("/sessions"));
    assert.equal(res.status, 401);
  });
});

describe("GET /sessions - limit handling", () => {
  // A scratch projects dir with 60 valid sessions so default/cap are testable.
  let scratch: string;
  let bigApp: ReturnType<typeof createApp>;

  before(() => {
    scratch = mkdtempSync(join(tmpdir(), "cw-server-limit-"));
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
    bigApp = createApp({ token: TOKEN, projectsDir: scratch });
  });

  after(() => rmSync(scratch, { recursive: true, force: true }));

  test("defaults to 10 sessions when no limit is given", async () => {
    const res = await bigApp.request(authed("/sessions"));
    const body = validateResponse(await res.json());
    assert.equal(body.sessions.length, 10);
  });

  test("clamps limit to the 50 hard cap", async () => {
    const res = await bigApp.request(authed("/sessions?limit=999"));
    assert.equal(res.status, 200);
    const body = validateResponse(await res.json());
    assert.equal(body.sessions.length, 50);
  });

  test("ignores a non-numeric limit and falls back to the default", async () => {
    const res = await bigApp.request(authed("/sessions?limit=notanumber"));
    assert.equal(res.status, 200);
    const body = validateResponse(await res.json());
    assert.equal(body.sessions.length, 10);
  });

  test("honors an explicit limit below the cap", async () => {
    const res = await bigApp.request(authed("/sessions?limit=5"));
    const body = validateResponse(await res.json());
    assert.equal(body.sessions.length, 5);
  });
});
