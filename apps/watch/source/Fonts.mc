import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// Lazy-loaded cache of the custom 0xProto bitmap fonts (see tools/fonts/). A
// font resource is not free to load, so each is loaded once on first use and
// reused for every subsequent draw.
module Fonts {
    var _big as FontResource? = null;
    var _med as FontResource? = null;
    var _sml as FontResource? = null;

    // Large - the usage dashboard hero number (lazy: only the usage view uses it).
    function big() as FontResource {
        if (_big == null) {
            _big = WatchUi.loadResource($.Rez.Fonts.claudemono_big) as FontResource;
        }
        return _big as FontResource;
    }

    // Medium weight - titles and headings.
    function medium() as FontResource {
        if (_med == null) {
            _med = WatchUi.loadResource($.Rez.Fonts.claudemono_med) as FontResource;
        }
        return _med as FontResource;
    }

    // Small weight - sub-labels and secondary text.
    function small() as FontResource {
        if (_sml == null) {
            _sml = WatchUi.loadResource($.Rez.Fonts.claudemono_sml) as FontResource;
        }
        return _sml as FontResource;
    }
}
