#!/usr/bin/env bats
# Task 1: QML notifications (NotificationServer + popups + DND chip) replace mako.

ROOT="$BATS_TEST_DIRNAME/.."
QS="$ROOT/profile/airootfs/etc/skel/.config/quickshell"

@test "notification server replaces mako" {
  grep -q 'NotificationServer' "$QS/shell.qml"
  grep -q '"notify"' "$QS/shell.qml"
  [ ! -d "$ROOT/profile/airootfs/etc/skel/.config/mako" ]
  ! grep -qE '^mako$' "$ROOT/profile/packages.x86_64"
  ! grep -rn 'mako' "$ROOT/profile/airootfs/usr/local/bin/cyberos-theme"
  ! grep -rn 'mako' "$ROOT/profile/airootfs/etc/skel/.config/hypr/hyprland.lua"
  [ -f "$QS/notify/NotifyCard.qml" ] && grep -q 'Theme.alert' "$QS/notify/NotifyCard.qml"
  grep -q 'invoke' "$QS/notify/NotifyCard.qml"
}

@test "mako is gone from the whole profile tree, not just the obvious spots" {
  ! grep -rn 'mako' "$ROOT/profile/" --include='*.lua' --include='*.sh' --include='cyberos-theme' 2>/dev/null
}

@test "onNotification tracks the notification so it lands in trackedNotifications" {
  # Notification.tracked is a settable bool (verified against the qmltypes:
  # read isTracked/write setTracked) -- the server itself does not
  # auto-track, so the handler must set it explicitly or nothing ever
  # appears in trackedNotifications.
  grep -q 'onNotification' "$QS/shell.qml"
  grep -qE '\.tracked = true' "$QS/shell.qml"
}

@test "NotificationServer is configured for body/image/actions" {
  grep -q 'keepOnReload: true' "$QS/shell.qml"
  grep -q 'actionsSupported: true' "$QS/shell.qml"
  grep -q 'imageSupported: true' "$QS/shell.qml"
  grep -q 'bodySupported: true' "$QS/shell.qml"
}

@test "notify ipc target exposes a dnd toggle" {
  grep -q 'target: "notify"' "$QS/shell.qml"
  grep -q 'function dnd(): void' "$QS/shell.qml"
}

@test "NotifyPopups: top-right anchored panel, exclusiveZone 0, hidden on empty/DND" {
  [ -f "$QS/notify/NotifyPopups.qml" ]
  grep -q 'PanelWindow' "$QS/notify/NotifyPopups.qml"
  grep -q 'top: true' "$QS/notify/NotifyPopups.qml"
  grep -q 'right: true' "$QS/notify/NotifyPopups.qml"
  grep -q 'exclusiveZone: 0' "$QS/notify/NotifyPopups.qml"
  grep -q 'aboveWindows: true' "$QS/notify/NotifyPopups.qml"
  grep -qE 'visible:.*dnd' "$QS/notify/NotifyPopups.qml"
}

@test "NotifyCard: urgency styling, expiry timer, dismiss on click" {
  grep -q 'NotificationUrgency' "$QS/notify/NotifyCard.qml"
  grep -q 'Critical' "$QS/notify/NotifyCard.qml"
  grep -q 'Timer' "$QS/notify/NotifyCard.qml"
  grep -q 'expireTimeout' "$QS/notify/NotifyCard.qml"
  grep -q '\.expire()' "$QS/notify/NotifyCard.qml"
  grep -q '\.dismiss()' "$QS/notify/NotifyCard.qml"
}

@test "bar: NotifyChip shows a bell glyph + tracked count, wired into Bar.qml" {
  [ -f "$QS/bar/NotifyChip.qml" ]
  grep -q 'NotifyChip' "$QS/bar/Bar.qml"
  grep -q 'trackedNotifications' "$QS/bar/NotifyChip.qml"
  grep -qE 'dnd' "$QS/bar/NotifyChip.qml"
}

@test "no raw PUA glyph bytes in the new notify surfaces (escapes only)" {
  ! grep -rlP '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]' "$QS/notify" "$QS/bar/NotifyChip.qml" --include='*.qml'
}

# Task 2: QML window switcher (Super+Tab) replaces `rofi -show window`.

HYPR="$BATS_TEST_DIRNAME/../profile/airootfs/etc/skel/.config/hypr"
STUB="$BATS_TEST_DIRNAME/hl-stub.lua"

run_hypr_config() {
  local cfgdir="$BATS_TEST_TMPDIR/hyprcfg/hypr"
  mkdir -p "$cfgdir"
  cp "$HYPR/theme.lua" "$cfgdir/theme.lua"
  XDG_CONFIG_HOME="$BATS_TEST_TMPDIR/hyprcfg" lua -e "dofile('$STUB'); dofile('$HYPR/hyprland.lua'); report()"
}

@test "WinSwitch.qml lists Hyprland toplevels" {
  [ -f "$QS/popups/WinSwitch.qml" ]
  grep -q 'Hyprland.toplevels' "$QS/popups/WinSwitch.qml"
}

@test "WinSwitch: PanelWindow, ScriptModel identity, Tab/arrows cycle, Return activates, Escape closes" {
  grep -q 'PanelWindow' "$QS/popups/WinSwitch.qml"
  grep -q 'ScriptModel' "$QS/popups/WinSwitch.qml"
  grep -q 'ObjectComparison.Identity' "$QS/popups/WinSwitch.qml"
  grep -q 'Qt.Key_Tab' "$QS/popups/WinSwitch.qml"
  grep -q 'Qt.Key_Down' "$QS/popups/WinSwitch.qml"
  grep -q 'Qt.Key_Up' "$QS/popups/WinSwitch.qml"
  grep -q 'Qt.Key_Return' "$QS/popups/WinSwitch.qml"
  grep -q 'Qt.Key_Escape' "$QS/popups/WinSwitch.qml"
  grep -q 'closeRequested' "$QS/popups/WinSwitch.qml"
}

@test "WinSwitch: focuses via Hyprland.dispatch, not a nonexistent activate()" {
  grep -q 'Hyprland.dispatch' "$QS/popups/WinSwitch.qml"
  ! grep -qE '\.activate\(\)' "$QS/popups/WinSwitch.qml"
}

@test "shell.qml: winswitch LazyLoader + IpcHandler mirror the launcher's toggle shape" {
  grep -q 'popups' "$QS/shell.qml"
  grep -q 'id: winswitch' "$QS/shell.qml"
  grep -q 'target: "winswitch"' "$QS/shell.qml"
  grep -q 'function toggle(): void' "$QS/shell.qml"
  grep -q 'onCloseRequested: winswitch.active = false' "$QS/shell.qml"
}

@test "Super+Tab dispatches the quickshell winswitch, rofi -show window is gone" {
  run run_hypr_config
  [ "$status" -eq 0 ]
  [[ "$output" == *"bindcmd SUPER + Tab :: qs ipc call winswitch toggle"* ]]
  ! grep -q 'rofi -show window' <<<"$output"
  ! grep -rq 'rofi -show window' "$HYPR/hyprland.lua"
}

@test "the other rofi binds (equal/X) are untouched by the Tab swap" {
  run run_hypr_config
  [ "$status" -eq 0 ]
  [[ "$output" == *"bindcmd SUPER + equal :: rofi -show calc -no-show-match -no-sort"* ]]
  [[ "$output" == *"bindcmd SUPER + X :: cliphist list | rofi -dmenu -p clipboard | cliphist decode | wl-copy"* ]]
}

@test "no raw PUA glyph bytes in popups/ (escapes only)" {
  ! grep -rlP '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]' "$QS/popups" --include='*.qml'
}

# Task 3: QML emoji picker (Super+period) replaces `rofi -show emoji`; data
# vendored once from rofi-emoji's all_emojis.txt.

@test "emoji.txt is vendored, non-empty, and carries a CC-BY-4.0 attribution header" {
  [ -s "$QS/emoji.txt" ]
  grep -qE '^# ' "$QS/emoji.txt"
  grep -qi 'rofi-emoji' "$QS/emoji.txt"
  grep -qi 'CC-BY-4.0' "$QS/emoji.txt"
  grep -qi 'unicode' "$QS/emoji.txt"
  # real, literal UTF-8 emoji glyphs -- not \uXXXX-escaped (R-s1): every
  # non-comment line's first byte sequence must NOT be a literal backslash-u.
  ! grep -qE '^\\u' "$QS/emoji.txt"
  # more than a token handful of entries
  n=$(grep -vcE '^#' "$QS/emoji.txt")
  [ "$n" -gt 1000 ]
}

@test "EmojiPicker.qml exists and reads emoji.txt via FileView" {
  [ -f "$QS/popups/EmojiPicker.qml" ]
  grep -q 'FileView' "$QS/popups/EmojiPicker.qml"
  grep -q 'emoji.txt' "$QS/popups/EmojiPicker.qml"
}

@test "EmojiPicker: GridView, ScriptModel identity, filter, copy via wl-copy stdin" {
  grep -q 'PanelWindow' "$QS/popups/EmojiPicker.qml"
  grep -q 'GridView' "$QS/popups/EmojiPicker.qml"
  grep -q 'ScriptModel' "$QS/popups/EmojiPicker.qml"
  grep -q 'ObjectComparison.Identity' "$QS/popups/EmojiPicker.qml"
  grep -qE 'columns:\s*8' "$QS/popups/EmojiPicker.qml"
  grep -q '"wl-copy"' "$QS/popups/EmojiPicker.qml"
  grep -q '\.write(' "$QS/popups/EmojiPicker.qml"
  grep -q 'stdinEnabled = false' "$QS/popups/EmojiPicker.qml"
  grep -q 'Qt.Key_Return' "$QS/popups/EmojiPicker.qml"
  grep -q 'Qt.Key_Escape' "$QS/popups/EmojiPicker.qml"
  grep -q 'closeRequested' "$QS/popups/EmojiPicker.qml"
}

@test "EmojiPicker: comment-skip does not swallow the '#'-prefixed keycap emoji rows" {
  # emoji.txt has two rows whose glyph itself starts with the literal '#'
  # character (the keycap sequences): "#️⃣ keycap: # ..." and "#⃣ keycap: # ...".
  # A parser that treats every line[0] === '#' as a comment would silently
  # drop both from the picker. The fix checks the SECOND character is
  # whitespace too (comment headers are always "# text"; the keycap glyphs'
  # second codepoint is a variation selector / combining mark, never a
  # space) -- assert that check is actually present in the source.
  grep -qE 'line\[1\]' "$QS/popups/EmojiPicker.qml"
  grep -q '#️⃣' "$QS/emoji.txt"
  grep -q '#⃣ ' "$QS/emoji.txt"
}

@test "shell.qml: emoji LazyLoader + IpcHandler mirror the launcher's toggle shape" {
  grep -q 'id: emoji' "$QS/shell.qml"
  grep -q 'target: "emoji"' "$QS/shell.qml"
  grep -q 'onCloseRequested: emoji.active = false' "$QS/shell.qml"
}

@test "Super+period dispatches the quickshell emoji picker, rofi -show emoji is gone" {
  run run_hypr_config
  [ "$status" -eq 0 ]
  [[ "$output" == *"bindcmd SUPER + period :: qs ipc call emoji toggle"* ]]
  ! grep -q 'rofi -show emoji' <<<"$output"
  ! grep -rq 'rofi -show emoji' "$HYPR/hyprland.lua"
}

@test "rofi-emoji is gone from packages; rofi and rofi-calc still present" {
  ! grep -qE '^rofi-emoji$' "$ROOT/profile/packages.x86_64"
  grep -qE '^rofi$' "$ROOT/profile/packages.x86_64"
  grep -qE '^rofi-calc$' "$ROOT/profile/packages.x86_64"
}
