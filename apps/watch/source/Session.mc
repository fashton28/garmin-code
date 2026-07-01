import Toybox.Lang;

// Lightweight in-memory model for one session, parsed from a single element of
// the `sessions` array in the /sessions response (see contract/contract.md).
//
// Parsing is defensive: the contract fields are read with type-checked
// fallbacks so a malformed row can never crash the menu build. Kept minimal to
// stay within the FR165's small heap.
class Session {
    public var id as String;
    public var project as String;
    public var title as String;
    public var lastActive as Number;
    public var messages as Number;
    public var active as Boolean;
    // Coarse activity state: "working" | "waiting" | "idle" (see contract).
    public var state as String;
    // Short model name the session last used, or "" if unknown.
    public var model as String;

    function initialize(data as Dictionary) {
        id = stringOr(data["id"], "");
        project = stringOr(data["project"], "");
        title = stringOr(data["title"], "Untitled");
        lastActive = numberOr(data["lastActive"]);
        messages = numberOr(data["messages"]);
        active = (data["active"] == true);
        state = stringOr(data["state"], "idle");
        model = stringOr(data["model"], "");
    }

    private function stringOr(value, fallback as String) as String {
        if (value instanceof Lang.String) {
            return value;
        }
        return fallback;
    }

    private function numberOr(value) as Number {
        if (value instanceof Lang.Number) {
            return value;
        }
        if (value instanceof Lang.Float || value instanceof Lang.Double || value instanceof Lang.Long) {
            return value.toNumber();
        }
        return 0;
    }
}
