import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The usage dashboard: a hero total, key stats, and a per-model output-token
// breakdown bar. Reads aggregates off its UsageController.
class UsageView extends WatchUi.View {
    private var _c as UsageController;

    // Segment colors for the model breakdown bar (top-first).
    private const BAR_COLORS = [0xFF5500, 0xF2A65A, Graphics.COLOR_LT_GRAY, Graphics.COLOR_DK_GRAY] as Array<Number>;

    function initialize(controller as UsageController) {
        View.initialize();
        _c = controller;
    }

    function onUpdate(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var cx = dc.getWidth() / 2;
        var cy = dc.getHeight() / 2;

        if (_c.failed) {
            dc.setColor(Graphics.COLOR_RED, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Fonts.medium(), "Can't load usage",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }
        if (!_c.loaded) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy, Fonts.small(), "Loading usage...",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        // Header.
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 150, Fonts.small(), "USAGE",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Hero: total (input + output) tokens.
        dc.setColor(0xFF5500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 92, Fonts.big(), fmt(_c.inputTokens + _c.outputTokens),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 56, Fonts.small(), "tokens",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Key stats.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy - 16, Fonts.small(), fmt(_c.sessions) + " sessions | " + fmt(_c.messages) + " msgs",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 8, Fonts.small(), fmt(_c.inputTokens) + " in | " + fmt(_c.outputTokens) + " out",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, cy + 30, Fonts.small(), fmt(_c.cacheReadTokens) + " cached",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // Model breakdown.
        drawModelBar(dc, cx, cy + 58, 220, _c.models);
    }

    // Stacked bar of model output-token share, plus the top model + its percent.
    private function drawModelBar(dc as Graphics.Dc, cx as Number, y as Number, w as Number, models as Array) as Void {
        var total = 0;
        for (var i = 0; i < models.size(); i++) {
            total += outOf(models[i]);
        }
        if (total <= 0) {
            return;
        }

        var x = cx - w / 2;
        var barH = 12;
        for (var i = 0; i < models.size() && i < BAR_COLORS.size(); i++) {
            var segW = (outOf(models[i]).toFloat() / total * w).toNumber();
            if (segW < 1) {
                segW = 1;
            }
            dc.setColor(BAR_COLORS[i], Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(x, y, segW, barH);
            x += segW;
        }

        var top = models[0] as Dictionary;
        var name = (top["name"] instanceof Lang.String) ? top["name"] as String : "";
        var pct = (outOf(top).toFloat() / total * 100).format("%.0f");
        dc.setColor(0xFF5500, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, y + 30, Fonts.small(), name + " " + pct + "%",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function outOf(m as Object) as Number {
        if (m instanceof Lang.Dictionary) {
            var v = m["outputTokens"];
            if (v instanceof Lang.Number) {
                return v;
            }
            if (v instanceof Lang.Float || v instanceof Lang.Long) {
                return v.toNumber();
            }
        }
        return 0;
    }

    // Compact number: 6689935 -> "6.7M", 657535 -> "657.5K", 26 -> "26".
    private function fmt(n as Number) as String {
        if (n >= 1000000000) {
            return (n.toFloat() / 1000000000.0).format("%.1f") + "B";
        }
        if (n >= 1000000) {
            return (n.toFloat() / 1000000.0).format("%.1f") + "M";
        }
        if (n >= 1000) {
            return (n.toFloat() / 1000.0).format("%.1f") + "K";
        }
        return n.toString();
    }
}
