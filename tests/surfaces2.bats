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
