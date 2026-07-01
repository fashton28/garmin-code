import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.Time;
import Toybox.WatchUi;

// Claude's coral/orange, used for the spark mark under the title.
const CLAUDE_CORAL as Number = 0xD97757;

// The focused (centered) row is indicated by tinting its TEXT with this accent
// color, rather than filling its background. Tweak to restyle the selection.
const HIGHLIGHT_COLOR as Graphics.ColorType = Graphics.COLOR_ORANGE;

// The sessions list, drawn as a WatchUi.CustomMenu so we control the focused-row
// highlight color. (WatchUi.Menu2's highlight is drawn by the system theme and
// can't be recolored, so we draw each row ourselves - see SessionRow.draw.)
//
// Row 0 is a fixed "Refresh" action (identifier :refresh) that re-runs the fetch;
// see SessionsMenuDelegate. Every following item is one session:
//   title      = session `title`
//   sub-label  = relative age + " - " + `project`, e.g. "8m ago - sonar", with a
//                leading "* " marker when the session is currently `active`
//   identifier = session `id` (short id), so a delegate can reference the row
//
// Relative ages are computed once against a single "now" snapshot taken when the
// menu is built (TimeFormat.relative), so every row is dated against the same
// instant and there is no per-row Time call.
class SessionsMenu extends WatchUi.CustomMenu {

    function initialize(sessions as Array<Session>) {
        CustomMenu.initialize(70, Graphics.COLOR_BLACK, {
            :focusItemHeight => 84,
            :title => new SessionsMenuTitle()
        });

        addItem(new SessionRow(:refresh, "Refresh", "Reload sessions", ""));

        var now = Time.now().value();
        for (var i = 0; i < sessions.size(); i++) {
            var s = sessions[i];
            var sub = TimeFormat.relative(s.lastActive, now) + " - " + s.project;
            addItem(new SessionRow(s.id, s.title, sub, s.state));
        }
    }
}

// The "Sessions" header plus a small Claude spark mark beneath it, drawn in the
// custom menu's title area.
class SessionsMenuTitle extends WatchUi.Drawable {

    function initialize() {
        Drawable.initialize({});
    }

    function draw(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (h * 0.36).toNumber(), Fonts.medium(), "Sessions",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        drawClaudeSpark(dc, cx, (h * 0.78).toNumber(), 11);
    }

    // A stylized Claude "spark": rays of alternating length radiating from a
    // center point, in Claude's coral. (A nod to the logo; swap for the real
    // asset as a bitmap if desired.)
    private function drawClaudeSpark(dc as Graphics.Dc, cx as Number, cy as Number, r as Number) as Void {
        dc.setColor(CLAUDE_CORAL, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(3);
        var rays = 12;
        for (var i = 0; i < rays; i++) {
            var a = i.toFloat() * (Math.PI * 2.0 / rays);
            var len = (i % 2 == 0) ? r : (r * 0.55).toNumber();
            var x = cx + (len * Math.cos(a)).toNumber();
            var y = cy + (len * Math.sin(a)).toNumber();
            dc.drawLine(cx, cy, x, y);
        }
        dc.setPenWidth(1);
    }
}

// One drawable list row: title on top, sub-label beneath. The focused row's
// text is tinted with HIGHLIGHT_COLOR.
class SessionRow extends WatchUi.CustomMenuItem {

    private var _title as String;
    private var _sub as String;
    private var _state as String;

    function initialize(id as Object, title as String, sub as String, state as String) {
        CustomMenuItem.initialize(id, {});
        _title = title;
        _sub = sub;
        _state = state;
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var focused = isFocused();

        // Focused row: tint the text with the accent color (no background fill).
        var titleColor = focused ? HIGHLIGHT_COLOR : Graphics.COLOR_WHITE;
        var subColor = focused ? HIGHLIGHT_COLOR : Graphics.COLOR_LT_GRAY;
        var cx = w / 2;
        var maxWidth = w - 64; // leave room for the state dot on the left

        drawStateDot(dc, h);

        var titleFont = Fonts.medium();
        var subFont = Fonts.small();

        dc.setColor(titleColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 13, titleFont, fit(dc, _title, titleFont, maxWidth),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(subColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 15, subFont, fit(dc, _sub, subFont, maxWidth),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Truncate text with a trailing "..." so it fits maxWidth pixels. Uses ASCII
    // dots (not a unicode ellipsis) to avoid FR165 system-font glyph gaps.
    private function fit(dc as Graphics.Dc, text as String, font as Graphics.FontType, maxWidth as Number) as String {
        if (dc.getTextWidthInPixels(text, font) <= maxWidth) {
            return text;
        }
        var s = text;
        while (s.length() > 1 && dc.getTextWidthInPixels(s + "...", font) > maxWidth) {
            s = s.substring(0, s.length() - 1);
        }
        return s + "...";
    }

    // A small state dot on the left, with a white halo so it reads on the dark
    // rows. No dot for the Refresh row.
    private function drawStateDot(dc as Graphics.Dc, h as Number) as Void {
        var color = stateColor(_state);
        if (color < 0) {
            return;
        }
        var x = 20;
        var y = h / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 8);
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(x, y, 6);
    }

    // Map a state to its dot color. -1 means "no dot" (e.g. the Refresh row).
    // green = working, yellow = waiting, gray = idle.
    private function stateColor(state as String) as Number {
        if (state.equals("working")) { return Graphics.COLOR_GREEN; }
        if (state.equals("waiting")) { return Graphics.COLOR_YELLOW; }
        if (state.equals("idle")) { return Graphics.COLOR_LT_GRAY; }
        return -1;
    }
}
