import Toybox.Lang;
import Toybox.WatchUi;

// Back stops the task's polling and returns to the task menu.
class TaskStatusDelegate extends WatchUi.BehaviorDelegate {
    private var _c as TaskController;

    function initialize(controller as TaskController) {
        BehaviorDelegate.initialize();
        _c = controller;
    }

    function onBack() as Boolean {
        _c.stop();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
