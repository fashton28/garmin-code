import Toybox.Lang;
import Toybox.WatchUi;

// Input delegate paired with StatusView (loading / empty / error states).
// Back pops the view; since a status view is always the root during these
// states, that exits the app. A manual refresh action is deferred to W3.
class StatusDelegate extends WatchUi.BehaviorDelegate {

    function initialize() {
        BehaviorDelegate.initialize();
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
