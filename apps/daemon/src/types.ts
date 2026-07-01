/**
 * The six-field session model from the frozen /sessions contract.
 * See contract/contract.md. No field beyond these six may be emitted.
 */
export interface Session {
  /** Short, stable session id (stem of the session UUID / filename). Non-empty. */
  id: string;
  /** Basename of the session's cwd. Non-empty. */
  project: string;
  /** aiTitle -> truncated lastPrompt -> "Untitled". Non-empty. */
  title: string;
  /** Session file mtime as a Unix epoch in seconds. */
  lastActive: number;
  /** Count of user + assistant lines in the session file. */
  messages: number;
  /** true if the file mtime is within the last 60 seconds. */
  active: boolean;
}

/** The full /sessions response body. */
export interface SessionsResponse {
  sessions: Session[];
}
