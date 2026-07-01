import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// A WatchUi.Menu2 built from the live /sessions response (see contract/contract.md).
//
// Row 0 is a fixed "Refresh" action (identifier :refresh) that re-runs the fetch;
// see SessionsMenuDelegate. Every following item is one session:
//   label      = session `title`
//   sub-label  = relative age + " - " + `project`, e.g. "8m ago - sonar", with a
//                leading "* " marker when the session is currently `active`
//   identifier = session `id` (short id), so a delegate can reference the row
//
// Relative ages are computed once against a single "now" snapshot taken when the
// menu is built (TimeFormat.relative), so every row is dated against the same
// instant and there is no per-row Time call.
class SessionsMenu extends WatchUi.Menu2 {

    function initialize(sessions as Array<Session>) {
        Menu2.initialize({ :title => "Sessions" });

        addItem(new WatchUi.MenuItem("Refresh", "Reload sessions", :refresh, null));

        var now = Time.now().value();
        for (var i = 0; i < sessions.size(); i++) {
            var s = sessions[i];
            var subLabel = TimeFormat.relative(s.lastActive, now) + " - " + s.project;
            if (s.active) {
                subLabel = "* " + subLabel;
            }
            addItem(new WatchUi.MenuItem(s.title, subLabel, s.id, null));
        }
    }
}
