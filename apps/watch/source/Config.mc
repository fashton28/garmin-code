// Compile-time configuration for ClaudeWatch (see PRD section 8).
//
// This file is COMMITTED with safe placeholder values so a fresh checkout
// compiles (CI-equivalent build + review gate). It must NEVER contain a real
// token.
//
// To run against your own daemon:
//   1. Edit the three constants below with your real Cloudflare tunnel URL and
//      the CLAUDEWATCH_TOKEN from apps/daemon/.env.
//   2. Stop git from ever seeing that secret:
//        git update-index --skip-worktree apps/watch/source/Config.mc
//      (undo later with --no-skip-worktree). This keeps your local edits out of
//      `git status` / commits while the placeholder stays in the repo.

using Toybox.Lang;

module Config {
    // Public HTTPS base URL of your Cloudflare tunnel, no trailing slash.
    // Placeholder resolves DNS-wise to nothing, so the app cleanly shows its
    // error state until you set a real host.
    const BASE_URL as Lang.String = "https://example.invalid";

    // Must match CLAUDEWATCH_TOKEN in apps/daemon/.env. Empty by default so no
    // real secret is ever committed.
    const TOKEN as Lang.String = "";

    // How many sessions to request (server caps at 50).
    const LIMIT as Lang.Number = 10;
}
