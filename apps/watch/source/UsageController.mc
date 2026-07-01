import Toybox.Communications;
import Toybox.Lang;
import Toybox.WatchUi;

// Fetches GET /usage and holds the aggregate for UsageView.
class UsageController {
    public var loaded as Boolean = false;
    public var failed as Boolean = false;
    public var sessions as Number = 0;
    public var messages as Number = 0;
    public var inputTokens as Number = 0;
    public var outputTokens as Number = 0;
    public var cacheReadTokens as Number = 0;
    // Array of { "name" => String, "outputTokens" => Number }, top-first.
    public var models as Array = [];

    function initialize() {
    }

    function load() as Void {
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :headers => { "Authorization" => "Bearer " + Config.TOKEN },
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
        };
        Communications.makeWebRequest(Config.BASE_URL + "/usage", null, options, method(:onLoad));
    }

    function onLoad(code as Number, data as Dictionary or String or Null) as Void {
        if (code == 200 && data instanceof Lang.Dictionary) {
            sessions = numOr(data["sessions"]);
            messages = numOr(data["messages"]);
            inputTokens = numOr(data["inputTokens"]);
            outputTokens = numOr(data["outputTokens"]);
            cacheReadTokens = numOr(data["cacheReadTokens"]);
            var m = data["models"];
            if (m instanceof Lang.Array) {
                models = m;
            }
            loaded = true;
        } else {
            failed = true;
        }
        WatchUi.requestUpdate();
    }

    private function numOr(v) as Number {
        if (v instanceof Lang.Number) {
            return v;
        }
        if (v instanceof Lang.Float || v instanceof Lang.Double || v instanceof Lang.Long) {
            return v.toNumber();
        }
        return 0;
    }
}
