import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

// Owns the /sessions fetch and drives the app between its four states:
//   loading -> (list | empty | error)
//
// The loading StatusView is already on screen (returned by getInitialView) when
// load() is called from the app's onStart. makeWebRequest's callback runs later
// on the UI thread; it swaps in the correct terminal view with switchToView.
//
// The app holds a reference to this controller for the request's lifetime so the
// bound callback method is not collected before the response settles.
class SessionController {

    // True while a /sessions request is in flight. Guards against overlapping
    // fetches (e.g. mashing Refresh): a second load() is ignored until onReceive
    // settles the first, so exactly one callback ever updates the view - no
    // duplicate or stale swaps.
    private var _inFlight as Boolean = false;

    function initialize() {
    }

    // Shows the loading state, then re-runs the fetch. Invoked by the sessions
    // menu's Refresh row. Ignored while a request is already in flight so a
    // stale loading view can't stomp an in-progress one.
    function refresh() as Void {
        if (_inFlight) {
            return;
        }
        showStatus("ClaudeWatch", "Loading...", "");
        load();
    }

    // Fires the GET /sessions request. Non-blocking: onReceive handles the rest.
    function load() as Void {
        if (_inFlight) {
            return;
        }
        _inFlight = true;
        var url = Config.BASE_URL + "/sessions?limit=" + Config.LIMIT.toString();
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => {
                "Authorization" => "Bearer " + Config.TOKEN
            },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(url, null, options, method(:onReceive));
    }

    // makeWebRequest callback. responseCode is the HTTP status on success, or a
    // negative Connect IQ transport code (BLE unavailable, timeout, ...).
    function onReceive(responseCode as Number, data as Dictionary or String or Null) as Void {
        _inFlight = false;
        if (responseCode == 200 && data instanceof Lang.Dictionary) {
            var sessions = parseSessions(data as Dictionary);
            if (sessions.size() == 0) {
                showStatus("No sessions", "Nothing active right now", "Press to retry");
            } else {
                WatchUi.switchToView(
                    new SessionsMenu(sessions),
                    new SessionsMenuDelegate(self),
                    WatchUi.SLIDE_IMMEDIATE);
            }
        } else {
            showStatus("Can't load", errorMessage(responseCode), "Press to retry");
        }
    }

    // Extracts the `sessions` array into Session models, skipping any malformed
    // entries. Returns an empty array if the field is missing or the wrong type.
    private function parseSessions(data as Dictionary) as Array<Session> {
        var result = [] as Array<Session>;
        var raw = data["sessions"];
        if (raw instanceof Lang.Array) {
            var arr = raw as Array;
            for (var i = 0; i < arr.size(); i++) {
                if (arr[i] instanceof Lang.Dictionary) {
                    result.add(new Session(arr[i] as Dictionary));
                }
            }
        }
        return result;
    }

    private function showStatus(heading as String, message as String, hint as String) as Void {
        WatchUi.switchToView(
            new StatusView(heading, message, hint),
            new StatusDelegate(self),
            WatchUi.SLIDE_IMMEDIATE);
    }

    // Maps a response code to a short, human hint plus the raw code so a user can
    // read out the exact failure. Covers the cases the contract/SDK call out:
    // auth failure, phone not connected, and timeouts.
    private function errorMessage(responseCode as Number) as String {
        var hint;
        if (responseCode == 401) {
            hint = "Auth failed";
        } else if (responseCode == Communications.BLE_CONNECTION_UNAVAILABLE
                || responseCode == Communications.BLE_HOST_TIMEOUT) {
            hint = "Phone not connected";
        } else if (responseCode == Communications.NETWORK_REQUEST_TIMED_OUT) {
            hint = "Timed out";
        } else {
            hint = "Error";
        }
        return hint + " (" + responseCode.toString() + ")";
    }
}
