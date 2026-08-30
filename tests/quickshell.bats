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
  run grep -rlE '"#[0-9A-Fa-f]{6}' "$QS" --include='*.qml'
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
