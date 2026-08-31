#!/usr/bin/env bats
ROOT="$BATS_TEST_DIRNAME/.."
INST="$ROOT/profile/airootfs/usr/share/cyberos/installer"
QMLLINT=/usr/lib/qt6/bin/qmllint
QMLDIRS=/tmp/claude-1000/-home-edbron-Work/9fdca27c-4540-4321-9795-683d0bdd0a18/scratchpad/qs/usr/lib/qt6/qml

@test "installer config exists with wrapper, and the GTK wizard is gone" {
  [ -f "$INST/shell.qml" ]
  head -1 "$ROOT/profile/airootfs/usr/local/bin/cyberos-install-gui" | grep -q '^#!/bin/sh'
  grep -q 'CYBEROS_INSTALLER_DRYRUN' "$ROOT/profile/airootfs/usr/local/bin/cyberos-install-gui"
  grep -q 'exec qs -p /usr/share/cyberos/installer' "$ROOT/profile/airootfs/usr/local/bin/cyberos-install-gui"
  ! grep -q 'import gi' "$ROOT/profile/airootfs/usr/local/bin/cyberos-install-gui"
}

@test "installer QML: no raw glyphs, no hex outside Theme.qml, parses" {
  ! grep -rlP '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]' "$INST" --include='*.qml'
  run grep -rlE "['\"]#[0-9A-Fa-f]{3,8}" "$INST" --include='*.qml'
  [ "$output" = "$INST/Theme.qml" ] || [ -z "$output" ]
  [ -x "$QMLLINT" ] || skip "qmllint absent"
  [ -d "$QMLDIRS" ] || skip "quickshell qml modules not available for qmllint"
  find "$INST" -name '*.qml' -print0 | xargs -0 -n1 "$QMLLINT" --bare -I "$QMLDIRS"
}

@test "env guard uses truthiness, never !== empty-string" {
  ! grep -rn 'env("[A-Z_]*") !==' "$INST"
}

@test "probe ports the exact exclusion and commands" {
  grep -q 'zram|loop|ram|sr|fd' "$INST/Probe.qml"
  grep -q 'lsblk.*-dnpo.*NAME,SIZE,TYPE,MODEL' "$INST/Probe.qml"
  grep -q 'findmnt.*-no.*SOURCE.*/run/archiso/bootmnt' "$INST/Probe.qml"
  grep -q 'sgdisk' "$INST/Probe.qml"
  grep -q 'timedatectl' "$INST/Probe.qml"
  grep -qE 'PKNAME' "$INST/Probe.qml"
}

@test "mode page ports the three modes and the 25 GiB gate" {
  for s in 'Install alongside' 'Erase the whole disk' 'Custom partitioning' '25' 'gparted' 'will be destroyed'; do
    grep -qF "$s" "$INST/pages/ModePage.qml"
  done
}

@test "disk page ports title, subtitle and the no-disks fallback verbatim" {
  grep -qF 'Choose a disk' "$INST/pages/DiskPage.qml"
  grep -qF 'The entire disk will be erased' "$INST/pages/DiskPage.qml"
  grep -qF 'no disks found' "$INST/pages/DiskPage.qml"
}

@test "WizState carries disk, mode default and freeGib" {
  grep -q 'property string disk' "$INST/WizState.qml"
  grep -q 'property string mode: "erase"' "$INST/WizState.qml"
  grep -q 'property int freeGib' "$INST/WizState.qml"
}
