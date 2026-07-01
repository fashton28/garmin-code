import Toybox.Lang;
import Toybox.WatchUi;

// Input delegate paired with StatusView (loading / empty / error states).
// Back pops the view; since a status view is always the root during these
// states, that exits the app. Pressing select or tapping asks the controller to
// re-fetch, giving the user an in-app retry from the empty and error states
// without relaunching. The controller's in-flight guard drops the request if one
// is already running, so overlapping presses can't start a second fetch.
class StatusDelegate extends WatchUi.BehaviorDelegate {
    private var _controller as SessionController;

    function initialize(controller as SessionController) {
        BehaviorDelegate.initialize();
        _controller = controller;
    }

    function onSelect() as Boolean {
        _controller.refresh();
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        _controller.refresh();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
