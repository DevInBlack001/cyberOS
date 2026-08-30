#!/usr/bin/env bats
ROOT="$BATS_TEST_DIRNAME/.."
QS="$ROOT/profile/airootfs/etc/skel/.config/quickshell"
QMLLINT=/usr/lib/qt6/bin/qmllint

@test "every QML file parses (qmllint; skips if absent)" {
  [ -x "$QMLLINT" ] || skip "qmllint not installed"
  find "$QS" -name '*.qml' -print0 | xargs -0 -n1 "$QMLLINT" --bare
}

@test "no raw private-use glyphs in any QML file -- \\uXXXX escapes only" {
  # PUA bytes are invisible in tool output; the waybar config lost 23 once.
  ! grep -rlP '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]' "$QS" --include='*.qml'
}

@test "no hex colours outside Theme.qml" {
  # Catches #RGB, #ARGB, #RRGGBB, #AARRGGBB in either quote style -- not just
  # the 6-digit double-quoted form (a single-quoted or shorthand hex literal
  # slipped past this test before it was tightened).
  run grep -rlE "['\"]#[0-9A-Fa-f]{3,8}" "$QS" --include='*.qml'
  [ "$output" = "$QS/Theme.qml" ] || [ -z "$output" ]
}

@test "the bar chips all go through Theme" {
  for f in Bar BarModule ClockChip WindowTitle; do
    grep -q 'Theme\.' "$QS/bar/$f.qml"
  done
}

@test "shell.qml hosts one bar per screen and the three popup loaders" {
  grep -q 'Variants' "$QS/shell.qml"
  grep -q 'Quickshell.screens' "$QS/shell.qml"
  for id in powerMenu launcher osd; do grep -q "$id" "$QS/shell.qml"; done
}

@test "workspaces: 5 persistent, activate on click, Hyprland-driven" {
  grep -q 'Hyprland.workspaces' "$QS/bar/Workspaces.qml"
  grep -q 'activate()' "$QS/bar/Workspaces.qml"
  grep -qE 'persistent|for.*1.*5|range' "$QS/bar/Workspaces.qml"
}

@test "audio: pipewire sink with tracker, click/right-click/scroll behaviours" {
  grep -q 'Pipewire.defaultAudioSink' "$QS/bar/Audio.qml"
  grep -q 'PwObjectTracker' "$QS/bar/Audio.qml"
  grep -q 'pavucontrol' "$QS/bar/Audio.qml"
}

@test "battery: hidden on desktops, warn/critical colours from Theme" {
  grep -q 'isLaptopBattery' "$QS/bar/Battery.qml"
  grep -q 'Theme.alert' "$QS/bar/Battery.qml"
}

@test "install button only exists on the live ISO" {
  grep -q '/run/archiso' "$QS/bar/InstallButton.qml"
  grep -q 'cyberos-install' "$QS/bar/InstallButton.qml"
}

@test "parity: every waybar right-side module has a quickshell counterpart" {
  for f in Tray.qml BluetoothChip.qml Audio.qml Network.qml SysStats.qml Battery.qml ClockChip.qml; do
    [ -f "$QS/bar/$f" ]
  done
}

@test "power menu replaces the rofi script with the same four actions" {
  [ ! -e "$ROOT/profile/airootfs/etc/skel/.config/rofi/powermenu.sh" ]
  ! grep -q 'powermenu.sh' "$ROOT/profile/profiledef.sh"
  for a in hyprlock 'hl.dsp.exit' 'systemctl.*reboot' 'systemctl.*poweroff'; do
    grep -qE "$a" "$QS/power/PowerMenu.qml"
  done
  grep -q '"power"' "$QS/shell.qml"   # ipc target
}

@test "osd handles the five ipc functions and swayosd is gone" {
  for fn in volumeUp volumeDown volumeMute brightnessUp brightnessDown; do
    grep -q "function $fn" "$QS/shell.qml"
  done
  ! grep -rq 'swayosd' "$ROOT/profile/airootfs/etc/skel/.config/hypr/hyprland.lua"
  ! grep -qE '^swayosd$' "$ROOT/profile/packages.x86_64"
  grep -q 'qs ipc call osd' "$ROOT/profile/airootfs/etc/skel/.config/hypr/hyprland.lua"
}

@test "osd: bottom panel with progress fill and hide timer, theme-coloured" {
  grep -q 'PanelWindow' "$QS/osd/Osd.qml"
  grep -q 'bottom: true' "$QS/osd/Osd.qml"
  grep -q 'Timer' "$QS/osd/Osd.qml"
  grep -q 'Theme\.' "$QS/osd/Osd.qml"
}

@test "osd: volume adjusts pipewire, brightness shells out to brightnessctl" {
  grep -q 'Pipewire.defaultAudioSink' "$QS/shell.qml"
  grep -q 'brightnessctl' "$QS/shell.qml"
}
