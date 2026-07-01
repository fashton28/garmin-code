# ClaudeWatch API contract (v1, frozen)

This is the single seam between the two codebases.
The watch app (`apps/watch`, Monkey C) and the daemon (`apps/daemon`, Node + TypeScript) both build against exactly this.
Do not change it without updating `fixtures/sessions.json` and both sides.

## Endpoint

```
GET /sessions?limit=10
Authorization: Bearer <token>
```

- `limit` is optional, defaults to `10`, and is hard-capped server-side at `50`.
- A missing or wrong bearer token returns HTTP `401` with no session data.
- Success returns HTTP `200` with the body below.

## Response body

```json
{
  "sessions": [
    {
      "id": "b0cf8046",
      "project": "sonar",
      "title": "Review entire repository for context",
      "lastActive": 1782903580,
      "messages": 764,
      "active": true,
      "state": "working",
      "model": "fable-5"
    }
  ]
}
```

## Field definitions

| Field        | Type    | Meaning |
|--------------|---------|---------|
| `id`         | string  | Short session id (stem of the session UUID / filename). Non-empty. |
| `project`    | string  | Basename of the session's `cwd`. Non-empty. |
| `title`      | string  | The session's `aiTitle` (last one seen in the file). Falls back to `lastPrompt` truncated to 60 chars, then to `"Untitled"`. Non-empty. |
| `lastActive` | integer | Session file mtime as a Unix epoch in **seconds**. |
| `messages`   | integer | Count of `user` + `assistant` lines in the session file. |
| `active`     | boolean | `true` if the file mtime is within the last 60 seconds. |
| `state`      | string  | Coarse activity state, one of `"working"`, `"waiting"`, `"idle"` (see below). |
| `model`      | string  | Short name of the model the session last used (e.g. `"fable-5"`), or `""` if unknown. |

### `state`

- `"working"` - Claude is actively processing.
- `"waiting"` - Claude finished a turn and is waiting for your input.
- `"idle"` - no recent activity.

The daemon derives this **hybridly**: a fresh state written by the optional
ClaudeWatch hooks (see `tools/hooks/`) wins; otherwise it falls back to a
heuristic over the file's freshness and last conversation turn.

## Guarantees

- Sessions are sorted by `lastActive` **descending** (newest first).
- The array is truncated to `limit` (default 10, max 50).
- No field beyond the eight above is present. Keep the payload lean for the FR165 heap.

## Tasks (v2)

Run a task inside a session, headlessly, from the watch. The daemon spawns
`claude -p` in the session's working directory with a fixed prompt and a scoped
tool allowlist (`--permission-mode acceptEdits`).

### Start a task

```
POST /sessions/:id/tasks
Authorization: Bearer <token>
{ "task": "create_pr" | "run_tests" | "review" }
```

- `202` → `{ "taskId": "<uuid>", "status": "running" }`
- `400` if `task` is not one of the three ids; `404` if the session id is unknown; `401` on bad token.

### Poll a task

```
GET /tasks/:id
Authorization: Bearer <token>
```

- `200` → `{ "id", "sessionId", "type", "status": "running"|"done"|"failed", "summary", "model" }`
- `404` if the task id is unknown.

`summary` is always a short human string reporting how it went (the PR URL for
`create_pr`, a pass/fail line for `run_tests`, a findings blurb for `review`).
`model` is the primary model that ran the task, short form (e.g. `"fable-5"`), or
`""` while still running / unknown. Tasks time out after 5 minutes.

## Usage (v2)

Overall usage across all sessions, for the watch dashboard.

```
GET /usage
Authorization: Bearer <token>
```

`200` →

```json
{
  "sessions": 26,
  "messages": 4132,
  "inputTokens": 657535,
  "outputTokens": 6032400,
  "cacheReadTokens": 928945987,
  "models": [{ "name": "opus-4-8", "outputTokens": 4558626 }]
}
```

`models` is the top few models by output tokens (short names), descending.

## Canonical fixture

`fixtures/sessions.json` is a representative 10-session response.
The watch app renders against it before the daemon exists; the daemon asserts its output matches this shape.
Validate at any time with:

```
node contract/validate.mjs
```
