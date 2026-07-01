import Toybox.Lang;
import Toybox.WatchUi;

// Handles task selection: kicks off the task and shows its live status view.
class TaskMenuDelegate extends WatchUi.Menu2InputDelegate {
    private var _sessionId as String;

    function initialize(sessionId as String) {
        Menu2InputDelegate.initialize();
        _sessionId = sessionId;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        if (id == :create_pr) {
            launch("create_pr", "Create PR");
        } else if (id == :run_tests) {
            launch("run_tests", "Run tests");
        } else if (id == :review) {
            launch("review", "Review code");
        }
    }

    private function launch(taskType as String, label as String) as Void {
        var controller = new TaskController(_sessionId, taskType, label);
        WatchUi.pushView(
            new TaskStatusView(controller),
            new TaskStatusDelegate(controller),
            WatchUi.SLIDE_LEFT);
        controller.start();
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
