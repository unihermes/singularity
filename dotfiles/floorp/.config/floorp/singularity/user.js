// Singularity - Floorp
// ~/.config/floorp/singularity/user.js
//
// Floorp's prefs. The profile's own user.js is generated from this file by
// quickshell/services/AppearanceSync.qml, with the look's colours appended,
// so edit this one: edits to the profile's copy are overwritten.

user_pref("media.webrtc.camera.allow-pipewire", true);
// Screenwise (github.com/unihermes/screenwise) is unsigned and
// sideloaded into the profile: allow it, and enable it without a prompt
user_pref("xpinstall.signatures.required", false);
user_pref("extensions.autoDisableScopes", 14);

// Size pages by the display's logical pixels on every monitor. Firefox's
// fractional scaling draws in the physical pixels of a display scaled below
// 1 (the 1080p one at 0.75 on the desktop), so pages there come out a
// different size than on the other monitor and layout.css.devPixelsPerPx
// can't match both. Without it the compositor scales Floorp down instead.
user_pref("widget.wayland.fractional-scale.enabled", false);

// No telemetry, data reporting or studies, and no Floorp experiments
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("datareporting.usage.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
user_pref("toolkit.telemetry.updatePing.enabled", false);
user_pref("toolkit.telemetry.bhrPing.enabled", false);
user_pref("toolkit.telemetry.firstShutdownPing.enabled", false);
user_pref("toolkit.telemetry.newProfilePing.enabled", false);
user_pref("toolkit.telemetry.shutdownPingSender.enabled", false);
user_pref("app.shield.optoutstudies.enabled", false);
user_pref("app.normandy.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.newtabpage.activity-stream.telemetry", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("floorp.experiments.participationPolicy", "never");
