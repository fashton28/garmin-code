#!/usr/bin/env node
// Zero-dependency validator for the frozen /sessions contract.
// Validates contract/fixtures/sessions.json against the field rules the
// daemon and watch app both rely on. Run: node contract/validate.mjs
//
// Exits 0 if the fixture is valid, 1 otherwise. This is the "test" that
// makes issue 0.1 demoable and keeps the contract honest over time.

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const here = dirname(fileURLToPath(import.meta.url));
const fixturePath = join(here, "fixtures", "sessions.json");

const errors = [];
const fail = (msg) => errors.push(msg);

let data;
try {
  data = JSON.parse(readFileSync(fixturePath, "utf8"));
} catch (err) {
  console.error(`Could not read/parse ${fixturePath}: ${err.message}`);
  process.exit(1);
}

if (typeof data !== "object" || data === null || Array.isArray(data)) {
  fail("root must be an object");
} else if (!Array.isArray(data.sessions)) {
  fail("root.sessions must be an array");
} else {
  if (data.sessions.length > 50) fail("sessions must not exceed 50 items (hard cap)");

  const isInt = (v) => Number.isInteger(v);
  const isNonEmptyString = (v) => typeof v === "string" && v.length > 0;

  let prevLastActive = Infinity;
  data.sessions.forEach((s, i) => {
    const at = `sessions[${i}]`;
    if (typeof s !== "object" || s === null) return fail(`${at} must be an object`);
    if (!isNonEmptyString(s.id)) fail(`${at}.id must be a non-empty string`);
    if (!isNonEmptyString(s.project)) fail(`${at}.project must be a non-empty string`);
    if (!isNonEmptyString(s.title)) fail(`${at}.title must be a non-empty string`);
    if (!isInt(s.lastActive) || s.lastActive < 0) fail(`${at}.lastActive must be a non-negative integer (unix seconds)`);
    if (!isInt(s.messages) || s.messages < 0) fail(`${at}.messages must be a non-negative integer`);
    if (typeof s.active !== "boolean") fail(`${at}.active must be a boolean`);

    // Contract guarantees newest-first ordering.
    if (isInt(s.lastActive)) {
      if (s.lastActive > prevLastActive) fail(`${at}.lastActive breaks descending sort order`);
      prevLastActive = s.lastActive;
    }

    const allowed = new Set(["id", "project", "title", "lastActive", "messages", "active"]);
    for (const key of Object.keys(s)) {
      if (!allowed.has(key)) fail(`${at} has unexpected field "${key}"`);
    }
  });
}

if (errors.length > 0) {
  console.error(`FAIL: ${fixturePath}`);
  for (const e of errors) console.error(`  - ${e}`);
  process.exit(1);
}

console.log(`OK: ${fixturePath} is a valid /sessions response (${data.sessions.length} sessions).`);
