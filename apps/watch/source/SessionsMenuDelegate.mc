import Toybox.Lang;
import Toybox.WatchUi;

// Input delegate for the sessions Menu2.
//
// The one interactive row so far is "Refresh" (identifier :refresh): selecting it
// asks the controller to re-fetch, which returns to the loading state and then
// rebuilds this menu from the fresh response. Selecting a session row is still a
// no-op (a detail view arrives in a later issue). Back pops the menu, exiting the
// app since it is the root view.
//
// The delegate holds the same SessionController the app kicked the first load off
// with, so refresh reuses that one in-flight-guarded instance (no new fetch path,
// no stale duplicate callbacks).
class SessionsMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _controller as SessionController;

    function initialize(controller as SessionController) {
        Menu2InputDelegate.initialize();
        _controller = controller;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        if (item.getId() == :refresh) {
            _controller.refresh();
            return;
        }
        // Session rows are a no-op for now. The item's identifier is the session id
        // (see SessionsMenu), which a future detail view will consume.
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
