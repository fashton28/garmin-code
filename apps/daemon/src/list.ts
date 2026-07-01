#!/usr/bin/env tsx
/**
 * `npm run list` - the demoable artifact for issue B1.
 *
 * Reads sessions from CLAUDE_PROJECTS_DIR (default ~/.claude/projects), validates
 * the result against the /sessions JSON Schema, and prints the contract body
 * `{ "sessions": [...] }` to stdout. Optional `--limit N`.
 */
import { readSessions } from "./sessionReader.js";
import { validateResponse } from "./schema.js";
import type { SessionsResponse } from "./types.js";

function parseLimit(argv: string[]): number | undefined {
  const flagIndex = argv.findIndex((a) => a === "--limit" || a === "-n");
  if (flagIndex !== -1) {
    const value = Number(argv[flagIndex + 1]);
    if (Number.isFinite(value)) return value;
  }
  const inline = argv.find((a) => a.startsWith("--limit="));
  if (inline) {
    const value = Number(inline.slice("--limit=".length));
    if (Number.isFinite(value)) return value;
  }
  return undefined;
}

function main(): void {
  const limit = parseLimit(process.argv.slice(2));
  const response: SessionsResponse = { sessions: readSessions({ limit }) };
  // Fail loudly if we ever drift from the frozen contract.
  validateResponse(response);
  process.stdout.write(`${JSON.stringify(response, null, 2)}\n`);
}

main();
