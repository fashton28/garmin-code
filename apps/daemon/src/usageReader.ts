/**
 * Aggregates overall Claude Code usage across all session transcripts for the
 * `GET /usage` dashboard: session/message counts, token totals, and a per-model
 * output-token breakdown.
 */
import { readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { resolveProjectsDir, shortModelName } from "./config.js";

export interface ModelUsage {
  name: string;
  outputTokens: number;
}

export interface UsageSummary {
  sessions: number;
  messages: number;
  inputTokens: number;
  outputTokens: number;
  cacheReadTokens: number;
  /** Top models by output tokens, descending. */
  models: ModelUsage[];
}

function isExcluded(name: string): boolean {
  return name.includes("-worktrees-") || name.endsWith("--config");
}

function toNum(value: unknown): number {
  return typeof value === "number" && Number.isFinite(value) ? value : 0;
}

/** Read and aggregate usage across every non-excluded session file. */
export function readUsage(projectsDir: string = resolveProjectsDir()): UsageSummary {
  const summary: UsageSummary = {
    sessions: 0,
    messages: 0,
    inputTokens: 0,
    outputTokens: 0,
    cacheReadTokens: 0,
    models: [],
  };
  const byModel = new Map<string, number>();

  let dirs: string[];
  try {
    dirs = readdirSync(projectsDir, { withFileTypes: true })
      .filter((d) => d.isDirectory() && !isExcluded(d.name))
      .map((d) => d.name);
  } catch {
    return summary;
  }

  for (const dir of dirs) {
    const dirPath = join(projectsDir, dir);
    let files: string[];
    try {
      files = readdirSync(dirPath).filter((f) => f.endsWith(".jsonl"));
    } catch {
      continue;
    }

    for (const file of files) {
      summary.sessions += 1;
      let raw: string;
      try {
        raw = readFileSync(join(dirPath, file), "utf8");
      } catch {
        continue;
      }
      for (const rawLine of raw.split("\n")) {
        const line = rawLine.trim();
        if (line.length === 0) continue;
        let entry: { type?: string; message?: { model?: string; usage?: Record<string, unknown> } };
        try {
          entry = JSON.parse(line);
        } catch {
          continue;
        }
        if (entry.type !== "assistant") continue;

        summary.messages += 1;
        const usage = entry.message?.usage ?? {};
        const out = toNum(usage.output_tokens);
        summary.inputTokens += toNum(usage.input_tokens);
        summary.outputTokens += out;
        summary.cacheReadTokens += toNum(usage.cache_read_input_tokens);

        const model = entry.message?.model;
        if (typeof model === "string" && model.length > 0 && model !== "<synthetic>" && out > 0) {
          byModel.set(model, (byModel.get(model) ?? 0) + out);
        }
      }
    }
  }

  summary.models = [...byModel.entries()]
    .map(([name, outputTokens]) => ({ name: shortModelName(name), outputTokens }))
    .sort((a, b) => b.outputTokens - a.outputTokens)
    .slice(0, 4);

  return summary;
}
