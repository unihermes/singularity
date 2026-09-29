# Per-Site Fullscreen

A browser extension for Floorp, Zen and other Firefox-based browsers that
chooses, per website, what happens when a page goes fullscreen:

- **In window** — the video or page fills the browser window; tabs and
  toolbars stay visible.
- **Full screen** — the page fills the whole screen, as browsers normally do.
- **Ask** — a small prompt offers both each time, with "Remember for this
  site".

The toolbar button sets the mode for the current site. **All sites…** opens
the options page, which sets the default for sites without a rule and lists
every rule. A rule for `example.com` also covers its subdomains. The rule
comes from the address in the tab, so a video embedded from another site
follows the site you are on.

It is plain WebExtension code with nothing tied to Linux, so the same `.xpi`
works on Windows and macOS.

## Install

Build the package (needs Python 3):

```bash
./build.sh        # writes ../per-site-fullscreen-<version>.xpi
```

The extension isn't signed by Mozilla. Floorp and Zen accept unsigned
extensions once signing is turned off:

1. Open `about:config` and set `xpinstall.signatures.required` to `false`.
2. Open `about:addons`, click the gear, choose **Install Add-on From File…**
   and pick the `.xpi`.

To update, bump `version` in `manifest.json`, build again, and install the new
file the same way.

Stock Firefox ignores that pref in release builds. It only takes the extension
once signed, for example as an unlisted add-on through `web-ext sign`.

On the Singularity desktop, `./install.sh` builds the package and sideloads it
into the default Floorp and Zen profiles. The browser registers it on its next
start, and it is active from the start after that.

## Notes

- **Full screen** needs `full-screen-api.ignore-widgets` left at its default,
  `false`. With it set to `true`, the browser keeps every fullscreen inside
  the window, and the options page shows a warning after a Full screen
  request stays in the window.
- **In window** makes the page believe it is fullscreen (`fullscreenElement`,
  `fullscreenchange`) and lays the element over the page in the top layer.
  CSS written for `:fullscreen` doesn't match there, so a site that styles
  its player only through `:fullscreen` may look slightly different.
- Esc leaves either kind of fullscreen.
- A `<video>`'s own fullscreen button bypasses the page's API. The extension
  follows the site's mode after the fact: the video goes fullscreen for a
  moment, then moves into the window.
