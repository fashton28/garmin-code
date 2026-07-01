# ClaudeWatch API contract (v1, frozen)

This is the single seam between the two codebases.
The watch app (`apps/watch`, Monkey C) and the daemon (`apps/daemon`, Node + TypeScript) both build against exactly this.
Do not change it without updating `fixtures/sessions.json`, the schema, and both sides.

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
      "active": true
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

## Guarantees

- Sessions are sorted by `lastActive` **descending** (newest first).
- The array is truncated to `limit` (default 10, max 50).
- No field beyond the six above is present. Keep the payload lean for the FR165 heap.

## Canonical fixture

`fixtures/sessions.json` is a representative 10-session response.
The watch app renders against it before the daemon exists; the daemon asserts its output matches this shape.
Validate at any time with:

```
node contract/validate.mjs
```
