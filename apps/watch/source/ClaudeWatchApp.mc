import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Application entry point for ClaudeWatch.
// W1: shows a static Menu2 of the 10 canonical sessions from contract/fixtures/sessions.json.
class ClaudeWatchApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up.
    function onStart(state as Dictionary?) as Void {
    }

    // onStop() is called when the application is exiting.
    function onStop(state as Dictionary?) as Void {
    }

    // Return the initial view. The sessions menu is itself a WatchUi.Menu2,
    // so it doubles as the root view; it is paired with its input delegate.
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new SessionsMenu(), new SessionsMenuDelegate()];
    }

}
