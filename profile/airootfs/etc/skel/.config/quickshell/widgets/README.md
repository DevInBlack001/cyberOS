# CyberOS bar widgets

Drop a `.qml` file in this directory (`~/.config/quickshell/widgets/`) and it
appears on the bar's right side. No shell edit, no restart -- `WidgetHost.qml`
watches this directory with a `FolderListModel`, so a dropped file appears on
the bar immediately.

## The contract

- **One file per widget.** Its root can be any QtQuick `Item`.
- **Filename order is bar order.** Widgets load alphabetically by filename,
  so a numeric prefix (`00-`, `10-`, `20-`...) controls placement relative to
  other widgets. See `00-example-uptime.qml`.
- **`Bar.BarModule` is recommended** for the root -- `import "../bar" as Bar`
  gets you the same chip shape (padding, hover highlight, click/scroll
  signals) every built-in module uses, for free.
- **Use `Cyber.Theme` for colour, never a hex literal.** `import ".." as
  Cyber` and read `Cyber.Theme.fg`, `.accent`, `.alert`, etc. A hardcoded
  `#RRGGBB` in a widget is a review rejection -- it won't follow
  Super+Shift+T's light/dark toggle.
- **Icons are `\uXXXX` escapes, never a raw glyph pasted into the source.**
  Copy-pasting the character itself risks losing invisible private-use
  codepoints -- an easy mistake to make and hard to spot by eye. Look up the
  codepoint in the JetBrainsMono Nerd Font cmap and write the escape.
- **A broken widget shows as a gap, not a crashed bar.** Each widget gets its
  own `Loader`; a QML error in your file logs `cyberos widget failed to
  load: <file>` to the qs log and leaves an empty slot where it would have
  been. The rest of the bar, and every other widget, keeps running.

## Why this exists

This is exactly what a `cyberos-plugin-*` package installs into this same
directory -- see `docs/SPEC.md` S5. Writing one by hand here is the same
contract a packaged plugin uses; there's no separate "real" widget API.

Import paths, worked through from this directory: `import "../bar" as Bar`
reaches the bar module classes, `import ".." as Cyber` reaches the shell
root (`Theme`, `OsdState`) -- the same two-levels-up relationship any other
`quickshell/*.qml` file has to its siblings.
