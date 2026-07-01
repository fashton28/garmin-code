import Toybox.Lang;
import Toybox.WatchUi;

// Input delegate for the sessions Menu2.
//
// W1 has no detail view yet: selecting a row is a no-op (the menu stays open),
// and the back button pops the menu, exiting the app since it is the root view.
// A session detail view is introduced in a later issue.
class SessionsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        // No-op for W1. The item's identifier is the session id (see SessionsMenu),
        // which a future detail view will consume.
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
