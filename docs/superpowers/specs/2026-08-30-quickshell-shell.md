# CyberOS Quickshell Shell — Spec

**Date:** 2026-08-30 · **Owner:** edbron · **Branch:** `shell/quickshell`
**Decisions made by the user, 2026-08-30:** Quickshell **replaces** waybar (no
dual-bar period), and the first milestone includes all four components: bar at
waybar parity, student widget API, OSD + power menu, launcher.

## Why

Quickshell (0.3.1, `extra`) is a QtQuick toolkit for building Wayland shells. For a
teaching distro it has a property waybar cannot offer: the entire shell is ordinary QML
that students can read, modify and extend — and the widgets/ drop-in API turns "write a
bar widget" into a one-file exercise that feeds the `cyberos-plugin-*` story in
docs/SPEC.md §5.

## What ships

One Quickshell configuration at `etc/skel/.config/quickshell/shell.qml` (the `qs`
default config path), owning four surfaces:

1. **Bar** — top panel, all monitors, at parity with the removed waybar:
   | region | contents (parity source: waybar config.jsonc) |
   |---|---|
   | left | launcher button (apps), live-ISO **Install CyberOS** button (only when `/run/archiso` exists), workspaces 1–10 (5 persistent), media (mpris, ignore browsers) |
   | center | focused window `title - class`, max ~55 chars |
   | right | tray, brightness, bluetooth (click: blueman-manager), audio (click: pavucontrol, right-click mute, scroll ±5%), network (click: nm-connection-editor), memory %, cpu % (click: foot -e btop), battery %+icon (warn 20 / critical 10), clock `HH:MM ddd` (click toggles date) , power button |
   Dropped deliberately: `custom/weather` (needs `wttrbar`, not in the image — never rendered), `idle_inhibitor` (moves to a later milestone), waybar's window-title rewrite table (apps not shipped).
2. **Power menu** — QML popup replacing `rofi/powermenu.sh`: Lock (hyprlock) / Log out (`hyprctl dispatch "hl.dsp.exit()"`) / Reboot / Shut down. Opened from the bar power button and battery module.
3. **OSD** — volume/brightness popups replacing swayosd, driven by the existing keybinds through `qs ipc call` (swayosd-server and swayosd-client leave the image).
4. **Launcher** — app grid/list over `DesktopEntries`, fuzzy filter, keyboard-first, replacing `rofi -show drun` on Super+D and the bar button. rofi itself STAYS in the image (clipboard, emoji, calc, window switcher still use it); only drun and the power menu move.

Plus a **widgets/ drop-in API**: every `*.qml` in `~/.config/quickshell/widgets/` is
auto-loaded into a reserved bar region, alphabetically; a broken widget must not take
down the bar (Loader isolation). One documented example ships that students copy.

## Theming contract

`cyberos-theme` generates `~/.config/quickshell/theme.json` (same palette as every other
surface, plus `mode`). The shell watches it with `FileView(watchChanges)` and re-themes
**live** — no shell restart on Super+Shift+T. Hex values in QML files are a review
rejection; everything reads `Theme.*`.

## Launch contract

`hyprland.lua`: `hl.exec_cmd("qs")` replaces waybar + swayosd-server autostarts;
Super+D dispatches the launcher via `qs ipc call launcher toggle`; volume/brightness
keys call `qs ipc call osd ...`. `cyberos-theme` reload: theme.json rewrite is picked up
by the file watcher (no pkill). waybar, its config, HANCORE css and
`rofi/powermenu.sh` are **removed** from the image; `waybar` leaves packages.x86_64,
`quickshell` enters it.

## Constraints

- Quickshell **0.3.1-1** API only (modules verified in the package: Hyprland, Io,
  Widgets, Wayland, Services.{Pipewire,SystemTray,UPower,Mpris,Notifications},
  Networking, Bluetooth).
- Every file must pass `qmllint` if available and load under `qs -p` headlessly in CI
  (Wayland not available there: load-check only).
- Glyphs: JetBrainsMono Nerd Font PUA codepoints, written as `\uXXXX` escapes in QML
  strings — never raw glyph bytes pasted into files (invisible in tool output; the
  waybar config lost 23 of them once).
- The live ISO's Install button behaviour must survive: visible only when
  `/run/archiso` exists; the installer's cleanup already deletes the .desktop file.
- Works in the safe-graphics session (software rendering): no shader effects.

## Out of scope (this milestone)

Lock screen (hyprlock stays), notifications daemon (mako stays), idle inhibitor,
weather, niri support.
