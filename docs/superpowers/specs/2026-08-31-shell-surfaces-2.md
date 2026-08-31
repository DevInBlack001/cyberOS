# CyberOS Shell Surfaces Phase 2 — Spec

**Date:** 2026-08-31 · **Owner:** edbron · **Branch:** `shell/quickshell-2` (created off main AFTER `installer/quickshell` merges; executes after that plan completes)
**User decisions (2026-08-31):** convert **notifications (mako)** and **rofi's four roles** to Quickshell. **Deferred by choice:** lock screen (hyprlock stays), greeter (SDDM stays).

## What ships

1. **Notification popups** replacing mako: a `NotificationServer` in the shell
   (`Quickshell.Services.Notifications`) rendering themed stacked popups top-right —
   app name, body, optional image/icon, action buttons (`NotificationAction.invoke()`),
   urgency styling (critical = `Theme.alert` border, no auto-expire), default
   expire ~6 s otherwise, click dismisses, a do-not-disturb toggle exposed as
   `qs ipc call notify dnd` plus a bar chip showing DND state and pending count.
   `mako` and its config leave the image; `cyberos-theme` drops its mako block and reload line.
2. **Window switcher** (Super+Tab): popup listing `Hyprland.toplevels` (title, app,
   workspace), arrows/Tab cycle, Return focuses (toplevel activation via the
   Hyprland module — verify the 0.3.1 idiom: HyprlandToplevel has `activate()`? if
   absent, `Hyprland.dispatch` focus by address), Escape closes.
3. **Emoji picker** (Super+period): grid over a vendored
   `emoji.txt` (generated once from rofi-emoji's `all_emojis.txt`, CC-BY-4.0
   Unicode data — attribution comment in the file header), filter field, Return
   copies via `wl-copy` and closes.
4. **Calculator** (Super+equal): input row evaluated through `qalc -t` (Process per
   edit, debounced), result line, Return copies result via `wl-copy`.
   `libqalculate` is added to packages.x86_64 explicitly (it arrived as a
   rofi-calc dep before).
5. **Clipboard history** (Super+X): list from `cliphist list` (line = id + preview),
   filter, Return pipes the selected line through `cliphist decode | wl-copy` —
   BUT the shell must never build that pipe as a shell string containing the
   selection; pass the cliphist LINE to `cliphist decode` via stdin
   (`Process.write`), then its stdout to `wl-copy` via a second Process stdin
   write. Preserves the old bind's behaviour without shell injection.
   `cliphist` stays (it is the store).

All five reuse the launcher's popup pattern (LazyLoader + IpcHandler targets:
`notify`, `winswitch`, `emoji`, `calc`, `clip`), keyboard-first, Theme tokens only,
`\uXXXX` glyphs, software-rendering safe. hyprland.lua rebinds Super+Tab/period/equal/X
to `qs ipc call …`; the rofi layer_rule and every `rofi`/`mako` reference leave the
config and the theme generator. Packages: −rofi −rofi-emoji −rofi-calc −mako,
+libqalculate. The blur layer_rule for "rofi" is deleted (the popups already live in
the "quickshell" namespace rule).

## Out of scope
hyprlock, SDDM/greetd, hypridle, wofi remnants in docs, the GNOME utility apps.

## Constraints
Quickshell 0.3.1 API only (Notifications module verified: NotificationServer with
trackedNotifications, Notification.{appName,body,actions,image,urgency,expireTimeout,
dismiss,expire}, NotificationAction.invoke); the shell's existing policy tests gate the
new QML automatically (same directory); every removal proven by grep over profile/;
suite green each task; VM verification task at the end (notify-send from a terminal,
each popup driven by real keybinds).
