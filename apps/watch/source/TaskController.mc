import Toybox.Communications;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Drives one watch-triggered task end to end:
//   POST /sessions/:id/tasks  -> taskId
//   GET  /tasks/:taskId        (polled) -> running -> done | failed
//
// The TaskStatusView reads `status`/`summary` off this controller and the
// controller calls requestUpdate() as they change. The view holds the
// controller for the request's lifetime so the bound callbacks survive.
class TaskController {
    // starting | running | done | failed
    public var status as String = "starting";
    public var summary as String = "";
    public var model as String = "";
    public var label as String;

    private var _sessionId as String;
    private var _taskType as String;
    private var _taskId as String or Null = null;
    private var _timer as Timer.Timer or Null = null;

    function initialize(sessionId as String, taskType as String, label as String) {
        _sessionId = sessionId;
        _taskType = taskType;
        self.label = label;
    }

    // Fire the POST that starts the task.
    function start() as Void {
        status = "starting";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :headers => {
                "Authorization" => "Bearer " + Config.TOKEN,
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_JSON
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(
            Config.BASE_URL + "/sessions/" + _sessionId + "/tasks",
            { "task" => _taskType },
            options,
            method(:onStart));
    }

    function onStart(code as Number, data as Dictionary or String or Null) as Void {
        if (code == 202 && data instanceof Lang.Dictionary && data["taskId"] != null) {
            _taskId = data["taskId"] as String;
            status = "running";
            poll();
            _timer = new Timer.Timer();
            _timer.start(method(:poll), 6000, true);
        } else {
            status = "failed";
            summary = "Couldn't start (" + code.toString() + ")";
        }
        WatchUi.requestUpdate();
    }

    // Poll the task's status.
    function poll() as Void {
        if (_taskId == null) {
            return;
        }
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => { "Authorization" => "Bearer " + Config.TOKEN },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(
            Config.BASE_URL + "/tasks/" + _taskId,
            null,
            options,
            method(:onPoll));
    }

    function onPoll(code as Number, data as Dictionary or String or Null) as Void {
        if (code == 200 && data instanceof Lang.Dictionary) {
            var st = data["status"];
            if (st instanceof Lang.String) {
                status = st;
            }
            var sm = data["summary"];
            if (sm instanceof Lang.String) {
                summary = sm;
            }
            var md = data["model"];
            if (md instanceof Lang.String) {
                model = md;
            }
            if (!status.equals("running")) {
                stop();
            }
        }
        WatchUi.requestUpdate();
    }

    // Stop polling (task settled, or the user backed out).
    function stop() as Void {
        if (_timer != null) {
            _timer.stop();
            _timer = null;
        }
    }
}
