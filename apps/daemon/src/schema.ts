/**
 * JSON Schema for the /sessions response plus an ajv-backed validator.
 *
 * This schema is the single source of truth for response validation in the
 * daemon: the CLI and the tests both call {@link validateResponse}. It mirrors
 * the field rules frozen in contract/contract.md.
 */
import { Ajv, type ValidateFunction } from "ajv";
import type { SessionsResponse } from "./types.js";

export const sessionsResponseSchema = {
  $schema: "http://json-schema.org/draft-07/schema#",
  $id: "https://claudewatch/schemas/sessions-response.json",
  title: "SessionsResponse",
  type: "object",
  required: ["sessions"],
  additionalProperties: false,
  properties: {
    sessions: {
      type: "array",
      maxItems: 50,
      items: {
        type: "object",
        required: ["id", "project", "title", "lastActive", "messages", "active", "state", "model"],
        additionalProperties: false,
        properties: {
          id: { type: "string", minLength: 1 },
          project: { type: "string", minLength: 1 },
          title: { type: "string", minLength: 1 },
          lastActive: { type: "integer", minimum: 0 },
          messages: { type: "integer", minimum: 0 },
          active: { type: "boolean" },
          state: { type: "string", enum: ["working", "waiting", "idle"] },
          model: { type: "string" },
        },
      },
    },
  },
} as const;

const ajv = new Ajv({ allErrors: true });
const validate: ValidateFunction = ajv.compile(sessionsResponseSchema);

/** Thrown when a response fails schema validation. */
export class ResponseValidationError extends Error {
  constructor(public readonly errors: string[]) {
    super(`Invalid /sessions response:\n  - ${errors.join("\n  - ")}`);
    this.name = "ResponseValidationError";
  }
}

/**
 * Validate a value against the /sessions schema.
 *
 * Also enforces the descending-by-lastActive ordering guarantee, which JSON
 * Schema alone cannot express. Returns the value narrowed to
 * {@link SessionsResponse}; throws {@link ResponseValidationError} otherwise.
 */
export function validateResponse(data: unknown): SessionsResponse {
  const errors: string[] = [];

  if (!validate(data)) {
    for (const err of validate.errors ?? []) {
      errors.push(`${err.instancePath || "/"} ${err.message ?? "is invalid"}`);
    }
  }

  if (errors.length === 0) {
    const { sessions } = data as SessionsResponse;
    let prev = Infinity;
    sessions.forEach((s, i) => {
      if (s.lastActive > prev) {
        errors.push(`/sessions/${i}/lastActive breaks descending sort order`);
      }
      prev = s.lastActive;
    });
  }

  if (errors.length > 0) throw new ResponseValidationError(errors);
  return data as SessionsResponse;
}
