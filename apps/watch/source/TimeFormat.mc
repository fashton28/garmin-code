import Toybox.Lang;

// Relative-time formatting for a session's `lastActive` Unix epoch (seconds).
//
// Kept in its own module so the bucketing is small, pure, and reusable: it takes
// the epoch and an explicit "now" (both epoch seconds, e.g. Time.now().value())
// and returns a short human string. No Time/Sys calls here, so the buckets are
// trivial to reason about and stay off the FR165 heap.
//
// Buckets (delta = now - lastActive, integer seconds):
//   delta < 60s      -> "now"
//   delta < 3600s    -> "Nm ago"   (whole minutes, 1..59)
//   delta < 86400s   -> "Nh ago"   (whole hours, 1..23)
//   otherwise        -> "Nd ago"   (whole days)
//
// Edge cases collapse to "now": a zero/negative delta (clock skew or a session
// stamped in the future) and a missing/zero epoch (Session's fallback for a
// malformed row) all read as "now" rather than a nonsense age.
module TimeFormat {

    function relative(lastActive as Number, now as Number) as String {
        if (lastActive <= 0) {
            return "now";
        }
        var delta = now - lastActive;
        if (delta < 60) {
            return "now";
        }
        if (delta < 3600) {
            return (delta / 60).toString() + "m ago";
        }
        if (delta < 86400) {
            return (delta / 3600).toString() + "h ago";
        }
        return (delta / 86400).toString() + "d ago";
    }
}
