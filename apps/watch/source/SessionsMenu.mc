import Toybox.Lang;
import Toybox.WatchUi;

// A WatchUi.Menu2 populated with the 10 canonical sessions.
//
// The values below are transcribed verbatim from contract/fixtures/sessions.json
// (Monkey C cannot parse the JSON at build time). Order matches the fixture,
// which the contract guarantees is sorted by lastActive descending (newest first).
//
// Each MenuItem:
//   label      = session `title`
//   sub-label  = `project` + " - " + a static last-active hint
//   identifier = session `id` (short id), so a delegate can reference the row
//
// W1 uses static last-active hints on purpose; real relative-time formatting
// from the numeric `lastActive` epoch is deferred to W3.
class SessionsMenu extends WatchUi.Menu2 {

    function initialize() {
        Menu2.initialize({ :title => "Sessions" });

        addSession("b0cf8046", "Review entire repository for context", "sonar", "active now");
        addSession("7a1e9c33", "Configure leader key with capital C", "mux", "8m ago");
        addSession("3f92d5a1", "Garmin Forerunner 165 configuration", "development", "42m ago");
        addSession("c85b7e20", "Understand project architecture and UI design", "final-personal-site", "3h ago");
        addSession("9d4a1f6b", "Fix slow directory loading", "thecodepreneur-network", "6h ago");
        addSession("1e6c8a94", "stripe-scaling-era-3d-replica", "fable5-testing", "20h ago");
        addSession("5b2f0d77", "Review project directory and gain context", "pyengine", "1d ago");
        addSession("8c3e11a5", "Add onboarding flow to landing page", "explano", "2d ago");
        addSession("a47d9e02", "Debug audio recording pipeline", "claycast", "3d ago");
        addSession("f0b6c8d3", "Wire up realtime multiplayer chat", "labhackathon", "4d ago");
    }

    // Adds one session row. Kept as a helper to keep the heap footprint small
    // and the item list readable.
    private function addSession(id as String, title as String, project as String, lastActiveHint as String) as Void {
        addItem(new WatchUi.MenuItem(
            title,
            project + " - " + lastActiveHint,
            id,
            null
        ));
    }
}
