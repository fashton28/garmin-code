import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Time;
import Toybox.WatchUi;

// The focused-row highlight is a vertical gradient between these two colors
// (top -> bottom). Connect IQ has no gradient primitive, so SessionRow paints it
// as a stack of thin interpolated bands. Tweak these to restyle the selection.
const HIGHLIGHT_TOP as Number = 0xFFAA00;     // amber
const HIGHLIGHT_BOTTOM as Number = 0xFF5500;  // deep orange

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

        addItem(new SessionRow(:refresh, "Refresh", "Reload sessions"));

        var now = Time.now().value();
        for (var i = 0; i < sessions.size(); i++) {
            var s = sessions[i];
            var sub = TimeFormat.relative(s.lastActive, now) + " - " + s.project;
            if (s.active) {
                sub = "* " + sub;
            }
            addItem(new SessionRow(s.id, s.title, sub));
        }
    }
}

// The "Sessions" header drawn in the custom menu's title area.
class SessionsMenuTitle extends WatchUi.Drawable {

    function initialize() {
        Drawable.initialize({});
    }

    function draw(dc as Graphics.Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Graphics.FONT_TINY, "Sessions",
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}

// One drawable list row: title on top, sub-label beneath. The focused row is
// painted with HIGHLIGHT_COLOR and its text flips to black for contrast.
class SessionRow extends WatchUi.CustomMenuItem {

    private var _title as String;
    private var _sub as String;

    function initialize(id as Object, title as String, sub as String) {
        CustomMenuItem.initialize(id, {});
        _title = title;
        _sub = sub;
    }

    function draw(dc as Graphics.Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var focused = isFocused();

        if (focused) {
            fillVerticalGradient(dc, w, h, HIGHLIGHT_TOP, HIGHLIGHT_BOTTOM);
        }

        var titleColor = focused ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
        var subColor = focused ? Graphics.COLOR_BLACK : Graphics.COLOR_LT_GRAY;
        var cx = w / 2;
        var maxWidth = w - 30;

        dc.setColor(titleColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 - 13, Graphics.FONT_TINY, fit(dc, _title, Graphics.FONT_TINY, maxWidth),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(subColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h / 2 + 15, Graphics.FONT_XTINY, fit(dc, _sub, Graphics.FONT_XTINY, maxWidth),
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

    // Paint a top->bottom vertical gradient across the row by drawing 2px bands,
    // each a color interpolated between `top` and `bottom`. (Connect IQ's Dc has
    // no gradient fill, so we fake it band by band.)
    private function fillVerticalGradient(dc as Graphics.Dc, w as Number, h as Number, top as Number, bottom as Number) as Void {
        for (var y = 0; y < h; y += 2) {
            var c = blendColor(top, bottom, y.toFloat() / h);
            dc.setColor(c, c);
            dc.fillRectangle(0, y, w, 2);
        }
    }

    // Linear-interpolate two 0xRRGGBB colors: t=0 -> a, t=1 -> b.
    private function blendColor(a as Number, b as Number, t as Float) as Number {
        var ar = (a >> 16) & 0xFF;
        var ag = (a >> 8) & 0xFF;
        var ab = a & 0xFF;
        var br = (b >> 16) & 0xFF;
        var bg = (b >> 8) & 0xFF;
        var bb = b & 0xFF;
        var r = (ar + (br - ar) * t).toNumber();
        var g = (ag + (bg - ag) * t).toNumber();
        var bl = (ab + (bb - ab) * t).toNumber();
        return (r << 16) | (g << 8) | bl;
    }
}
