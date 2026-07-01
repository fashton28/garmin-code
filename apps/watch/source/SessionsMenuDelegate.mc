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
        if (item.getId() == :usage) {
            var usage = new UsageController();
            WatchUi.pushView(new UsageView(usage), new UsageDelegate(), WatchUi.SLIDE_LEFT);
            usage.load();
            return;
        }
        // A session row: open the task menu for it. The identifier is the short
        // session id the daemon's task endpoints expect.
        var sessionId = item.getId() as String;
        var header = "Session";
        var model = "";
        if (item instanceof SessionRow) {
            header = (item as SessionRow).rowProject();
            model = (item as SessionRow).rowModel();
        }
        WatchUi.pushView(new TaskMenu(header, model), new TaskMenuDelegate(sessionId), WatchUi.SLIDE_LEFT);
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
