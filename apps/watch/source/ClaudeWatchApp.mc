import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

// Application entry point for ClaudeWatch.
//
// W2: on start the app shows a loading StatusView and kicks off a GET /sessions
// request via SessionController, which then swaps in the live sessions menu, an
// empty state, or an error state depending on the response.
class ClaudeWatchApp extends Application.AppBase {

    // Retained for the request's lifetime so the bound web-request callback is
    // not garbage-collected before the response arrives.
    private var _controller as SessionController?;

    function initialize() {
        AppBase.initialize();
    }

    // onStart() is called on application start up.
    function onStart(state as Dictionary?) as Void {
        _controller = new SessionController();
        _controller.load();
    }

    // onStop() is called when the application is exiting.
    function onStop(state as Dictionary?) as Void {
        _controller = null;
    }

    // The initial view is the loading state; SessionController replaces it once
    // the /sessions request settles.
    function getInitialView() as [WatchUi.Views] or [WatchUi.Views, WatchUi.InputDelegates] {
        return [new StatusView("ClaudeWatch", "Loading..."), new StatusDelegate()];
    }

}
