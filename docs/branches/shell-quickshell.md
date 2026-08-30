# Branch: `shell/quickshell`

**State:** verified in the VM, awaiting merge · **Owner:** @edbron
**Spec:** `docs/superpowers/specs/2026-08-30-quickshell-shell.md` · **Plan:** `docs/superpowers/plans/2026-08-30-quickshell-shell.md`

## Charter
One Quickshell (QML) shell replaces waybar, swayosd and rofi's drun/power-menu roles:
bar at waybar parity, power menu, OSD, launcher, and a students' widget drop-in API —
all themed live from `cyberos-theme` via a watched `theme.json`. rofi stays for
window/emoji/calc/clipboard.

## Verified on the build-15 encrypted install (Task 8, 2026-08-30)
| Check | Result |
|---|---|
| Bar renders at login: workspaces, media, tray, bluetooth, audio, network, mem/cpu, clock, power | ✓ |
| Battery hidden on a batteryless VM; Install button absent off the live ISO | ✓ |
| Example uptime widget loads with `XDG_CONFIG_HOME` unset (the C1 case) | ✓ |
| **Live re-theme**: `cyberos-theme light` flips the running bar with no restart | ✓ after fix |
| Launcher (Super+D): opens, icon grid, typing `fire` filters to Firefox, Escape closes | ✓ |
| OSD on a real volume key: bottom-centre pill, themed progress | ✓ |
| Power menu (`qs ipc call power toggle`): four actions, keyboard selection, aboveWindows | ✓ |
| Broken widget file: silently isolated, bar survives | ✓ (twice, accidentally) |
| Live ADD of a widget file while the shell runs | ✗ — does not appear; loads at shell start only (README documents this) |

## Defects found only by running it
- **`FileView.watchChanges` never re-reads** — it only emits `fileChanged`; without
  `onFileChanged: reload()` the shell keeps its login-time palette forever and
  `Super+Shift+T` re-themes everything *except* the shell. Invisible to every static
  test. Fixed (`7b03879`) and proven live.
- **FolderListModel does not live-add files under qs** on this stack — the widget API is
  load-at-start, and the README says so rather than promising hot-reload.

## Traps for future work here
- The QML policy tests gate raw glyph bytes and hex colours — write `\uXXXX`, read `Theme.*`.
- qs's layer-shell namespace is literally `quickshell` (layer rules depend on it).
- Never hand-type QML into the guest through sendkey — shell quoting eats it; ship files
  on a CD image instead.
- `Quickshell.env()` returns `null` for unset vars — truthiness, never `!== ""`.
