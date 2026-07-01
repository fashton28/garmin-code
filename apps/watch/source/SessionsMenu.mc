import Toybox.Lang;
import Toybox.WatchUi;

// A WatchUi.Menu2 built from the live /sessions response (see contract/contract.md).
//
// Each MenuItem:
//   label      = session `title`
//   sub-label  = `project` + (" - active" when the session is currently active)
//   identifier = session `id` (short id), so a delegate can reference the row
//
// The sub-label is intentionally minimal: real relative-time formatting of the
// numeric `lastActive` epoch is W3's job. The `active` flag is cheap to surface
// now and gives the list a useful "live" hint without any date math.
class SessionsMenu extends WatchUi.Menu2 {

    function initialize(sessions as Array<Session>) {
        Menu2.initialize({ :title => "Sessions" });

        for (var i = 0; i < sessions.size(); i++) {
            var s = sessions[i];
            var subLabel = s.active ? (s.project + " - active") : s.project;
            addItem(new WatchUi.MenuItem(s.title, subLabel, s.id, null));
        }
    }
}
