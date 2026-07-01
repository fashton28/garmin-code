import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// The menu of tasks that can be run in a session. Item identifiers map to the
// daemon's task types (see contract "Tasks"). Styled like the sessions list:
// mono font, orange text on the focused row. The header shows the session's
// (short) project name and model so nothing overflows.
class TaskMenu extends WatchUi.CustomMenu {

    function initialize(project as String, model as String) {
        CustomMenu.initialize(64, Graphics.COLOR_BLACK, {
            :focusItemHeight => 76,
            :title => new TaskMenuTitle(project, model)
        });
        addItem(new TaskRow(:create_pr, "Create PR"));
        addItem(new TaskRow(:run_tests, "Run tests"));
        addItem(new TaskRow(:review, "Review code"));
    }
}

// Header showing which session the tasks act on, and the model it runs on.
class TaskMenuTitle extends WatchUi.Drawable {
    private var _title as String;
    private var _model as String;

    function initialize(title as String, model as String) {
        Drawable.initialize({});
        _title = title;
        _model = model;
    }

    function draw(dc as Graphics.Dc) as Void {
        var cx = dc.getWidth() / 2;
        var h = dc.getHeight();
        var hasModel = !_model.equals("");

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (hasModel ? h * 0.36 : h * 0.5).toNumber(), Fonts.small(),
            fit(dc, _title, dc.getWidth() - 40),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        if (hasModel) {
            dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, (h * 0.72).toNumber(), Fonts.small(), "via " + _model,
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    private function fit(dc as Graphics.Dc, text as String, maxWidth as Number) as String {
        if (dc.getTextWidthInPixels(text, Fonts.small()) <= maxWidth) {
            return text;
        }
        var s = text;
        while (s.length() > 1 && dc.getTextWidthInPixels(s + "...", Fonts.small()) > maxWidth) {
            s = s.substring(0, s.length() - 1);
        }
        return s + "...";
    }
}

// One task option: a centered label, orange when focused.
class TaskRow extends WatchUi.CustomMenuItem {
    private var _label as String;

    function initialize(id as Object, label as String) {
        CustomMenuItem.initialize(id, {});
        _label = label;
    }

    function draw(dc as Graphics.Dc) as Void {
        var color = isFocused() ? Graphics.COLOR_ORANGE : Graphics.COLOR_WHITE;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(dc.getWidth() / 2, dc.getHeight() / 2, Fonts.medium(), _label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
