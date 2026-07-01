import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// A single full-screen view used for every non-list state: loading, empty, and
// error. It draws a centered heading with a short message below it. Using one
// view for all three keeps the heap footprint small; the controller swaps its
// text per state.
class StatusView extends WatchUi.View {
    private var _heading as String;
    private var _message as String;
    private var _hint as String;

    function initialize(heading as String, message as String, hint as String) {
        View.initialize();
        _heading = heading;
        _message = message;
        _hint = hint;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;
        dc.drawText(cx, cy - 18, Fonts.medium(), _heading,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.drawText(cx, cy + 16, Fonts.small(), _message,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        if (!_hint.equals("")) {
            dc.drawText(cx, cy + 40, Fonts.small(), _hint,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }
}
