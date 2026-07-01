import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Timer;
import Toybox.WatchUi;

// Live status of a running task: the task label, the model, a color-coded status
// line, an animated spinner while running, and the (wrapped) result summary once
// done. Reads state off its TaskController.
class TaskStatusView extends WatchUi.View {
    private var _c as TaskController;
    private var _frame as Number = 0;
    private var _anim as Timer.Timer or Null = null;

    function initialize(controller as TaskController) {
        View.initialize();
        _c = controller;
    }

    // Animate the spinner while the view is on screen.
    function onShow() as Void {
        if (_anim == null) {
            _anim = new Timer.Timer();
            _anim.start(method(:onAnim), 60, true);
        }
    }

    function onHide() as Void {
        if (_anim != null) {
            _anim.stop();
            _anim = null;
        }
    }

    function onAnim() as Void {
        _frame += 1;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var cx = w / 2;
        var cy = dc.getHeight() / 2;
        var running = _c.status.equals("running") || _c.status.equals("starting");

        // Task label.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 66, Fonts.medium(), _c.label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Model line, once known.
        if (!_c.model.equals("")) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 44, Fonts.small(), "via " + _c.model,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        // Status line, color-coded.
        dc.setColor(statusColor(_c.status), Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 18, Fonts.medium(), statusText(_c.status),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (running) {
            drawSpinner(dc, cx, cy + 34, 22);
        } else if (!_c.summary.equals("")) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            drawWrapped(dc, cx, cy + 12, w - 44, Fonts.small(), _c.summary);
        }
    }

    // A rotating arc spinner.
    private function drawSpinner(dc as Graphics.Dc, cx as Number, cy as Number, r as Number) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawCircle(cx, cy, r);
        dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
        var start = (_frame * 18) % 360;
        dc.drawArc(cx, cy, r, Graphics.ARC_COUNTER_CLOCKWISE, start, start + 90);
        dc.setPenWidth(1);
    }

    private function statusText(status as String) as String {
        if (status.equals("running")) { return "Running..."; }
        if (status.equals("done")) { return "Done"; }
        if (status.equals("failed")) { return "Failed"; }
        return "Starting...";
    }

    private function statusColor(status as String) as Graphics.ColorType {
        if (status.equals("done")) { return Graphics.COLOR_GREEN; }
        if (status.equals("failed")) { return Graphics.COLOR_RED; }
        return Graphics.COLOR_ORANGE;
    }

    // Draw text wrapped to maxWidth, centered, starting at topY (up to 5 lines).
    private function drawWrapped(dc as Graphics.Dc, cx as Number, topY as Number, maxWidth as Number, font as Graphics.FontType, text as String) as Void {
        var lineH = dc.getFontHeight(font) + 2;
        var lines = wrap(dc, text, font, maxWidth);
        for (var i = 0; i < lines.size() && i < 5; i++) {
            dc.drawText(cx, topY + i * lineH, font, lines[i],
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    // Greedy word wrap; long tokens (e.g. URLs) are hard-split by character.
    private function wrap(dc as Graphics.Dc, text as String, font as Graphics.FontType, maxWidth as Number) as Array<String> {
        var words = split(text, " ");
        var lines = [] as Array<String>;
        var cur = "";
        for (var i = 0; i < words.size(); i++) {
            var word = words[i];
            while (dc.getTextWidthInPixels(word, font) > maxWidth) {
                var part = "";
                var j = 0;
                while (j < word.length() && dc.getTextWidthInPixels(part + word.substring(j, j + 1), font) <= maxWidth) {
                    part = part + word.substring(j, j + 1);
                    j++;
                }
                if (part.equals("")) {
                    part = word.substring(0, 1);
                    j = 1;
                }
                if (!cur.equals("")) {
                    lines.add(cur);
                    cur = "";
                }
                lines.add(part);
                word = word.substring(j, word.length());
            }
            var candidate = cur.equals("") ? word : (cur + " " + word);
            if (dc.getTextWidthInPixels(candidate, font) <= maxWidth) {
                cur = candidate;
            } else {
                if (!cur.equals("")) {
                    lines.add(cur);
                }
                cur = word;
            }
        }
        if (!cur.equals("")) {
            lines.add(cur);
        }
        return lines;
    }

    private function split(str as String, sep as String) as Array<String> {
        var out = [] as Array<String>;
        var rem = str;
        var idx = rem.find(sep);
        while (idx != null) {
            out.add(rem.substring(0, idx));
            rem = rem.substring(idx + sep.length(), rem.length());
            idx = rem.find(sep);
        }
        out.add(rem);
        return out;
    }
}
