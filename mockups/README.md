# Style exploration

Open `style-exploration.html` in a browser. The first five choices refine the
existing styles; Rail, Notch, Ledger, Capsule and Bevel are new proposals.
These are review mockups, not registered shell styles or settled design choices.

The reference is `CLAUDE.md` and the Styles, Flyouts, Controls, Type and Colour
sections of `dotfiles/quickshell/.config/quickshell/DESIGN.md`, with stock values
from `services/Styles.js` and `services/Theme.qml`. All proposals share the
grayscale palette, indigo accent, bold mono type, 300px desktop flyout width and
34px leading volume reading. Each proposal changes the bar, frames, section
boundaries, selection marks and controls together. Narrow previews stack the
flyout and settings specimen for inspection; that is not a shell layout change.

Volume, mute, application volume, output selection, settings tabs and finish
previews are local interactions. Motion is described rather than played.
Sound settings and System buttons show local navigation placeholders.

Verification: checked all ten choices in Chromium at 320, 736 and 1280px for
horizontal overflow and runtime errors; exercised the interactive controls and
visually reviewed desktop and narrow screenshots. No production QML changed.
