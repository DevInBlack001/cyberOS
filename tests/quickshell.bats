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
  for f in Tray.qml Brightness.qml BluetoothChip.qml Audio.qml Network.qml SysStats.qml Battery.qml ClockChip.qml; do
    [ -f "$QS/bar/$f" ]
  done
}

@test "brightness chip: reads brightnessctl, hides with no device, scroll adjusts" {
  grep -q 'brightnessctl' "$QS/bar/Brightness.qml"
  grep -q 'hasDevice' "$QS/bar/Brightness.qml"
  grep -q 'visible: hasDevice' "$QS/bar/Brightness.qml"
  grep -q 'onScrolled' "$QS/bar/Brightness.qml"
  grep -q 'execDetached' "$QS/bar/Brightness.qml"
}

@test "bar: Brightness sits between Tray and BluetoothChip (waybar order)" {
  awk '/RowLayout {/{f++} f==2 && /Tray|Brightness|BluetoothChip/{print; if (/BluetoothChip/) exit}' "$QS/bar/Bar.qml" \
    | tr -d ' \t\n' | grep -q 'Tray{}Brightness{}BluetoothChip{}'
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

@test "launcher is DesktopEntries-driven and bound to Super+D" {
  grep -q 'DesktopEntries' "$QS/launcher/Launcher.qml"
  grep -q '"launcher"' "$QS/shell.qml"
  grep -q 'qs ipc call launcher toggle' "$ROOT/profile/airootfs/etc/skel/.config/hypr/hyprland.lua"
  ! grep -q 'rofi -show drun' "$ROOT/profile/airootfs/etc/skel/.config/hypr/hyprland.lua"
  grep -q 'rofi -show calc' "$ROOT/profile/airootfs/etc/skel/.config/hypr/hyprland.lua"  # rofi stays for calc/clip until later tasks
}

@test "launcher: centred focusable panel, GridView + filter, noDisplay excluded" {
  grep -q 'PanelWindow' "$QS/launcher/Launcher.qml"
  grep -q 'focusable: true' "$QS/launcher/Launcher.qml"
  grep -q 'GridView' "$QS/launcher/Launcher.qml"
  grep -q 'noDisplay' "$QS/launcher/Launcher.qml"
  grep -q 'execute()' "$QS/launcher/Launcher.qml"
  grep -q 'closeRequested' "$QS/launcher/Launcher.qml"
}

@test "bar: apps chip is the first left module, toggles the launcher" {
  grep -q 'launcher.activeAsync = true' "$QS/bar/Bar.qml"
  grep -q 'tooltip: "Applications"' "$QS/bar/Bar.qml"
  # must precede InstallButton -- first module in the left RowLayout
  awk '/RowLayout {/{f=1} f && /Applications|InstallButton/{print; if (/InstallButton/) exit}' "$QS/bar/Bar.qml" \
    | head -1 | grep -q 'Applications'
}

@test "widget host isolates failures and loads alphabetically" {
  grep -q 'FolderListModel\|folder' "$QS/bar/WidgetHost.qml"
  grep -qE 'Loader' "$QS/bar/WidgetHost.qml"
  [ -f "$QS/widgets/00-example-uptime.qml" ]
  [ -f "$QS/widgets/README.md" ]
}

@test "waybar and swayosd are fully gone; quickshell ships" {
  [ ! -d "$ROOT/profile/airootfs/etc/skel/.config/waybar" ]
  ! grep -qE '^waybar$' "$ROOT/profile/packages.x86_64"
  ! grep -qE '^swayosd$' "$ROOT/profile/packages.x86_64"
  grep -qE '^quickshell$' "$ROOT/profile/packages.x86_64"
  grep -q 'exec_cmd("qs")' "$ROOT/profile/airootfs/etc/skel/.config/hypr/hyprland.lua"
  ! grep -q 'waybar' "$ROOT/profile/airootfs/etc/skel/.config/hypr/hyprland.lua"
  ! grep -q 'waybar' "$ROOT/profile/airootfs/usr/local/bin/cyberos-theme"
}

@test "qmldir registers both Theme and OsdState as singletons" {
  grep -q 'singleton Theme' "$QS/qmldir"
  grep -q 'singleton OsdState' "$QS/qmldir"
}

# C1: Quickshell.env() returns "" (empty string), never null/undefined, so a
# `!== ""` guard is *always* true and the HOME fallback branch is dead code.
# With XDG_CONFIG_HOME unset (the CyberOS default), Theme.qml and
# WidgetHost.qml both silently resolved to "" + "/quickshell/..." -- a
# relative path under the qs process's CWD -- instead of $HOME/.config.
# bats cannot run qs itself, so this is a static (belt-and-braces) check on
# top of the live smoke-test verification in the report.
@test "C1: no XDG_CONFIG_HOME truthiness bug in Theme.qml / WidgetHost.qml" {
  ! grep -q 'env("XDG_CONFIG_HOME") !== ' "$QS/Theme.qml"
  ! grep -q 'env("XDG_CONFIG_HOME") !== ' "$QS/bar/WidgetHost.qml"
}

@test "C1: cyberos-theme writes theme.json under \$HOME/.config with no XDG_CONFIG_HOME" {
  run env -u XDG_CONFIG_HOME HOME="$BATS_TEST_TMPDIR/home" \
    bash "$ROOT/profile/airootfs/usr/local/bin/cyberos-theme" dark
  [ "$status" -eq 0 ]
  [ -f "$BATS_TEST_TMPDIR/home/.config/quickshell/theme.json" ]
}

@test "Theme.qml reloads on fileChanged -- watchChanges alone never re-reads" {
  # Found in the Task 8 VM pass: without onFileChanged: reload() the shell
  # keeps its login-time palette and the live re-theme contract is dead.
  grep -q 'onFileChanged: reload()' "$QS/Theme.qml"
}

@test "the stray About Xfce entry from libxfce4ui is hidden" {
  f="$ROOT/profile/airootfs/etc/skel/.local/share/applications/xfce4-about.desktop"
  [ -f "$f" ]
  grep -q '^NoDisplay=true' "$f"
}

# Security: Text's default textFormat (AutoText) auto-detects and renders
# HTML-like content. BarModule's label carries MPRIS track metadata and
# WindowTitle carries a window's own title -- both set by something this
# desktop does not control -- so either could otherwise inject markup into
# the system bar.
@test "bar chip label/icon and the window title are rendered as plain text" {
  grep -q 'textFormat: Text.PlainText' "$QS/bar/WindowTitle.qml"
  awk '/text: chip\.label/,/^ *}/' "$QS/bar/BarModule.qml" | grep -q 'textFormat: Text.PlainText'
}
