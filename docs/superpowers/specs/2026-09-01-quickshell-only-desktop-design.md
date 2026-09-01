# Quickshell-only desktop — design

**Date:** 2026-09-01
**Status:** approved (design), pending implementation plan
**Supersedes the app half of:** `docs/superpowers/plans/2026-09-01-qt6-quickshell-migration.md` (PR #16). That branch's Wi-Fi/Bluetooth panels, launcher categories, GTK purge and theme rework all stand; only its KDE **application** choices are reversed here.

## 1. Goal

Every desktop application CyberOS controls is a Quickshell (QML) surface. No GTK apps, no KDE apps, no GNOME apps ship on the ISO.

## 2. The boundary, stated exactly

Three things survive that a naive reading of "no GTK, no KDE" would delete. Each is deliberate:

| Survivor | Why it stays |
|---|---|
| **Firefox** | No QML surface can replace a browser. It bundles its own GTK internally; that is Mozilla's build, not a system GTK app. It also *replaces Okular* — `pdf.js` is the ISO's PDF viewer. |
| **VS Code** | Same reasoning (Electron). Students need a real editor; neovim is on the ISO as the terminal alternative. |
| **`xdg-desktop-portal-kde`** | A headless D-Bus service, not a KDE app: no window, no menu entry. It is the ISO's only FileChooser backend — without it Firefox and VS Code lose native Open/Save dialogs, because `xdg-desktop-portal-hyprland` implements no FileChooser. **⚠️ Correction (verified in the VM, 2026-09-01):** an earlier draft of this row claimed "no KDE Gear dependency chain". That was **wrong**. `xdg-desktop-portal-kde` depends on `plasma-workspace` (55.56 MiB) and the KDE Frameworks stack — `kio`, `kio-fuse`, `kiconthemes`, `kirigami`, `kdeclarative`, `knotifications`, `kwayland`, `kwindowsystem`, `kglobalaccel`, `kstatusnotifieritem`, `kitemviews`, `kcrash`, `kservice`. This is why `kio-extras` and `breeze-icons` remain installed even though both were dropped from the explicit package list. Keeping this portal therefore keeps a large part of KDE on the ISO, which is in tension with the "no KDE" goal; the alternatives are documented in §2.1. |

### 2.1 Open decision: the FileChooser portal

The choice to keep `xdg-desktop-portal-kde` was made on the incorrect premise corrected above. The real options are:

1. **Keep it** — native Qt file dialogs for Firefox/VS Code, at the cost of `plasma-workspace` + KDE Frameworks on the ISO.
2. **Drop it** — no FileChooser portal at all. Firefox and VS Code fall back to their own built-in file dialogs (both ship one), so file open/save still works; it just isn't a native Qt dialog and won't match the desktop's look. Removes the entire KDE dependency chain, fully satisfying "no KDE".
3. **Swap for `xdg-desktop-portal-gtk`** — a GTK file dialog, pulling GTK3 (already present for Firefox) instead of KDE Frameworks. Smaller net addition than option 1, but contradicts "no GTK".

This is a user decision and has not been made unilaterally. The branch currently implements option 1.

`gtk3` also remains on the ISO as a transitive dependency of Firefox. That is a library, not an app. **The test for "is this allowed" is: does it put a window, launcher entry, or tray icon in front of the student?** Firefox and VS Code do, and are justified above. Nothing else GTK/KDE/GNOME may.

## 3. What leaves

From `profile/packages.x86_64`, all added by PR #16:

`dolphin`, `ark`, `okular`, `gwenview`, `kate`, `kcalc`, `partitionmanager`, `pavucontrol-qt`, `kio-extras`, `kio-fuse`, `ffmpegthumbs`, `kdegraphics-thumbnailers`, `breeze-icons`.

Kept from that set: `xdg-desktop-portal-kde` (§2), `udisks2` (removable-media mounting, a daemon with no UI), `adwaita-cursors` (a cursor theme — toolkit-agnostic bitmaps).

## 4. What replaces each role

| Role | Replacement | New code? |
|---|---|---|
| File manager | **Files** — new QML surface | yes |
| Image viewer | **Images** — new QML surface | yes |
| Audio mixer | **Mixer** — new QML panel | yes |
| Archives | Files' extract action shelling out to `7z` / `unzip` (both already on the ISO) | part of Files |
| PDF viewer | Firefox (`pdf.js`) | no |
| Text editor | VS Code, neovim | no |
| Calculator | the existing QML Calc popup (`Super+=`) | no |
| Partitioning | `cfdisk` / `parted`, which the CLI installer already drives | no |

## 5. Architecture

### 5.1 One process, many surfaces

The three new surfaces live in the **existing** `qs` process alongside the bar, launcher and panels, each behind a `LazyLoader`, each opened by an `IpcHandler`. This is the pattern PR #16 established for the Wi-Fi and Bluetooth panels, and it is why those panels cost so little to build.

`.desktop` entries therefore exec into the running shell:

```
Exec=qs ipc call files open %f
```

**Accepted trade-off:** a fatal error inside Files would take down the bar with it, because they share a process. `LazyLoader` already contains construction errors (a broken surface fails to load rather than killing the shell), and every surface is `qmllint`-checked plus VM-tested before merge. A separate `qs -c` instance per app would isolate crashes but needs its own config tree, its own theme reload path, and its own startup cost — not worth it for three surfaces.

### 5.2 Window type

Files and Images are **real toplevel windows**, not layer-shell panels: `FloatingWindow` (verified present as `FloatingWindowInterface` in `Quickshell/_Window`, exposing `title`, `minimumSize`, `maximumSize`, `minimized`, `maximized`, `fullscreen`). They tile, they appear in the window switcher, they behave like applications.

The Mixer is a **`PanelWindow`**, anchored top-right like the Wi-Fi and Bluetooth panels, because it is a bar-chip popup, not an app.

### 5.3 Verified API surface

Everything below was read from this machine's qmltypes on 2026-09-01 (Quickshell 0.3.1, Qt 6.11.2). The implementation plan must not invent beyond it.

- **`Qt.labs.folderlistmodel`** (ships in `qt6-declarative`, already on the ISO): `folder`, `parentFolder`, `nameFilters`, `sortField`, `sortReversed`, `showFiles`, `showDirs`, `showDirsFirst`, `showHidden`, `count`, `status`; methods `get(i, role)`, `isFolder(i)`, `indexOf(url)`. Backs both Files' directory listing and Images' next/previous walk.
- **`Quickshell.Services.Pipewire`**: `Pipewire.nodes`, `defaultAudioSink`, `preferredDefaultAudioSink` (writable — this is how the Mixer switches output device), `ready`. `PwNode`: `id`, `name`, `description`, `nickname`, `isSink`, `isStream`, `type`, `properties`, `audio`, `ready`. `PwNodeAudio`: `muted`, `volume`, `channels`, `volumes`. `PwNodeType`: `AudioSink`, `AudioSource`, `AudioOutStream`, `AudioInStream`, … `PwNodePeakMonitor`: `node`, `enabled`, `peak`, `peaks`. `PwObjectTracker` keeps nodes bound, exactly as `bar/Audio.qml` already does.
- **`Quickshell.Io`**: `Process`, `FileView`.
- **`Quickshell.Widgets`**: `IconImage`, `WrapperRectangle`, `ClippingRectangle`.
- **`Quickshell`**: `DesktopEntries`, `ScriptModel`, `LazyLoader`, `Quickshell.iconPath()`, `Quickshell.execDetached()`.

### 5.4 Two tooling gaps found during design

Both are toolkit-agnostic CLI additions, not apps:

1. **`xdg-utils` is not on the ISO.** Nothing currently provides `xdg-open`, because dolphin opened files through KIO internally. Files needs it to hand a double-clicked file to its registered handler. `xdg-utils` is a set of POSIX shell scripts with no GTK/KDE dependency. **Add it.**
2. **`gio trash` left with `gvfs`** (removed in PR #16), so nothing implements the FreeDesktop trash spec. Files must not use `rm`. **Add `trash-cli`** (a Python CLI implementing the spec) and call `trash-put`.

## 6. The three surfaces

### 6.1 Files — `apps/Files.qml`

A `FloatingWindow`, default 1000×640, opened by `Super+E` and by `qs ipc call files open <path>`.

- **Sidebar:** a fixed list — Home, Desktop, Documents, Downloads, Pictures, Projects — resolved against `$HOME`. **Not** parsed from `~/.config/user-dirs.dirs`: that file does not exist in the live session (verified — `xdg-user-dirs-update` only runs at firstboot on an *installed* system, while `customize_airootfs.sh:13` creates exactly these five directories for the live user). A fixed list is correct on both. Removable media is v2 — enumerating it needs a UDisks2 D-Bus binding Quickshell does not expose.
- **Main view:** grid of entries from `FolderListModel` with `showDirsFirst: true`, icons via `Quickshell.iconPath()` (folder icon for dirs, mime-generic for files), name elided to one line.
- **Navigation:** double-click a directory to enter; Backspace or a breadcrumb click to go up; the breadcrumb is the path split on `/`.
- **Opening files:** `Quickshell.execDetached(["xdg-open", path])`.
- **Actions (right-click menu):** Open, Extract here (only for `.zip/.7z/.tar*/.gz/.rar`, runs `7z x` in the containing dir), Open terminal here (`foot -D <dir>`), Move to Trash (`trash-put`), Copy path.
- **Explicitly v2, not in this design:** rename, copy/cut/paste, multi-select, drag-and-drop, thumbnails, search. Shipping a solid browse-and-open beats a half-built file-operations engine.

### 6.2 Images — `apps/Images.qml`

A `FloatingWindow`, opened by `qs ipc call images open <file>` and set as the mimeapps handler for image types.

- Displays the image with `fillMode: PreserveAspectFit`; `+`/`-`/scroll zoom, `0` resets to fit, `1` sets 1:1, drag to pan when zoomed.
- Left/Right arrows walk the containing directory's images, using a `FolderListModel` with `nameFilters` for image extensions and `indexOf()` to find the current file's position.
- Escape closes; the title bar shows filename and pixel dimensions.

### 6.3 Mixer — `popups/Mixer.qml`

A `PanelWindow` anchored top-right, replacing `pavucontrol-qt` as the bar speaker chip's click target (`qs ipc call mixer toggle`).

- **Output device section:** every node with `type === PwNodeType.AudioSink`, one row each, radio-style selection writing `Pipewire.preferredDefaultAudioSink`; the selected row carries the master volume slider and mute button.
- **Applications section:** every node with `type === PwNodeType.AudioOutStream`, one row per playing app — name from `node.properties["application.name"]` falling back to `node.description`, its own volume slider and mute.
- **Input section:** default source volume, mute, and a live level meter driven by `PwNodePeakMonitor` (`enabled` only while the panel is open, mirroring how the Wi-Fi panel scopes `scannerEnabled`).
- Empty states: "No output devices" / "Nothing is playing" — the QEMU VM has a dummy sink and no streams, so both paths will be exercised in testing.

## 7. Rewiring

- **`profile/airootfs/etc/skel/.config/mimeapps.list`** — PR #16 pointed it at KDE `.desktop` ids that will no longer exist. Rewrite: images → `cyberos-images.desktop`; `inode/directory` → `cyberos-files.desktop`; `application/pdf` → `firefox.desktop`; text → `code.desktop`; audio/video → `mpv.desktop`; http(s) → `firefox.desktop`.
- **`.desktop` entries** for Files and Images at `/usr/local/share/applications/` — a package-unowned path, the same one `metasploit.desktop` uses (archiso fails the build on package-owned airootfs paths). Categories `System;FileManager;` and `Graphics;Viewer;` so the launcher's existing category chips pick them up with no launcher change.
- **`hyprland.lua`** — `local files = "dolphin"` becomes the IPC call; the float-utilities window rule drops `pavucontrol-qt` and `org.kde.kcalc` (both gone) and gains nothing, since Files and Images are tiled app windows by design.
- **`bar/Audio.qml`** — click target `pavucontrol-qt` → `qs ipc call mixer toggle`.
- **`cyberos-theme`** — the qt6ct and kdeglobals writes stay (Qt apps and the portal still read them); the GTK3 `settings.ini` write stays for Firefox. No change.

## 8. Testing

Same shape that verified PR #16, which caught real defects:

- **bats** — a `tests/quickshell-apps.bats` asserting each surface's file exists, uses the APIs §5.3 names, is wired into `shell.qml` with an `IpcHandler` and `LazyLoader`, and that no removed package name survives as a functional reference. Plus a packages test for the removals and the two CLI additions.
- **`qmllint`** on every new QML file (parse-level; the ISO's real type resolution only exists in the VM).
- **QEMU live boot** — for each surface: open it, exercise its primary path (Files: navigate into a directory, open a file, extract an archive; Images: open a PNG, arrow to the next; Mixer: see the dummy sink, move its slider), and confirm `journalctl` reports zero QML errors. Plus a `pacman -Q` check that every §3 package is absent and `xdg-utils`/`trash-cli` present.

## 9. Sequencing

1. **Merge PR #16** — the verified base. Its panels are the pattern the new surfaces copy.
2. Branch `desktop/quickshell-only`:
   - Task A: packages (remove §3, add `xdg-utils` + `trash-cli`) and the mimeapps/desktop-entry/bind/chip rewiring that does not depend on the new surfaces existing yet.
   - Task B: Mixer (cheapest — the Pipewire binding is already proven in `bar/Audio.qml`).
   - Task C: Images (medium — FolderListModel walk, zoom/pan).
   - Task D: Files (largest — sidebar, breadcrumb, grid, context actions).
   - Task E: sweep, full suite, ISO build, VM checklist, PR.

B, C and D touch disjoint files apart from `shell.qml` and `tests/`, so each is independently reviewable.

## 10. Honest risk

**Files v1 will be less capable than dolphin** — no rename, no copy/paste, no multi-select. For a student ISO whose file work is mostly "find the thing, open the thing, extract the archive I downloaded", that is an acceptable v1 and the operations can land later. If it proves too thin in the VM pass, the fallback is `yazi` (a terminal file manager, no toolkit at all) while the QML surface matures — a package swap, not a redesign.
