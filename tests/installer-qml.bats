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
  # A bare `! cmd` mid-body does NOT trip bash's `set -e` when cmd "fails"
  # (i.e. the negated command's own non-zero status) -- bash carves
  # !-negated commands out of errexit's early-exit rule. That silently
  # turned this into a no-op: a real raw glyph in the tree would print a
  # match and still leave this line's own exit status (from `!`) unable to
  # fail the test. `run` + an explicit `[ -z "$output" ]` check instead,
  # matching the pattern the hex-colour check right below already used.
  run grep -rlP '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]' "$INST" --include='*.qml'
  [ -z "$output" ]
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

@test "validators port the exact rules and messages" {
  grep -qF '[a-z_][a-z0-9_-]*' "$INST/pages/AccountPage.qml"
  grep -qF 'Passwords do not match' "$INST/pages/AccountPage.qml"
  grep -qF 'must be different partitions' "$INST/pages/CustomPage.qml"
  grep -qF 'at least 8 characters' "$INST/pages/OptionsPage.qml"
  grep -qF 'Africa/Accra' "$INST/pages/OptionsPage.qml"
}

@test "WizState carries custom/account/options answers with the right defaults" {
  grep -q 'property string rootPart' "$INST/WizState.qml"
  grep -q 'property string efiPart' "$INST/WizState.qml"
  grep -q 'property bool formatEfi: false' "$INST/WizState.qml"
  grep -q 'property string user: "student"' "$INST/WizState.qml"
  grep -q 'property string host: "cyberos"' "$INST/WizState.qml"
  grep -q 'property string password' "$INST/WizState.qml"
  grep -q 'property string tz' "$INST/WizState.qml"
  grep -q 'property string fs: "ext4"' "$INST/WizState.qml"
  grep -q 'property int swapGib: 4' "$INST/WizState.qml"
  grep -q 'property bool encrypt: false' "$INST/WizState.qml"
  grep -q 'property string luksPass' "$INST/WizState.qml"
}

@test "custom/account/options pages pin the remaining exact copy" {
  grep -qF 'No partitions on this disk. Create some first.' "$INST/pages/CustomPage.qml"
  grep -qF 'Root (/)' "$INST/pages/CustomPage.qml"
  grep -qF 'Will be formatted' "$INST/pages/CustomPage.qml"
  grep -qF 'EFI system partition' "$INST/pages/CustomPage.qml"
  grep -qF 'Format the EFI partition' "$INST/pages/CustomPage.qml"
  grep -qF "Leave off to keep another OS's bootloader" "$INST/pages/CustomPage.qml"
  grep -qF 'Username must be lowercase letters, digits, - or _' "$INST/pages/AccountPage.qml"
  grep -qF 'Password cannot be empty' "$INST/pages/AccountPage.qml"
  grep -qF 'Computer name cannot be empty' "$INST/pages/AccountPage.qml"
  grep -qF 'TextInput.Password' "$INST/pages/AccountPage.qml"
  grep -qF 'GiB, 0 for none' "$INST/pages/OptionsPage.qml"
  grep -qF 'LUKS2. You will be asked for this passphrase at every boot.' "$INST/pages/OptionsPage.qml"
  grep -qF 'An empty passphrase would produce a disk nobody can open.' "$INST/pages/OptionsPage.qml"
  grep -qF 'The passphrases do not match.' "$INST/pages/OptionsPage.qml"
  grep -qF 'TextInput.Password' "$INST/pages/OptionsPage.qml"
}

@test "argv is pinned to the CLI contract and secrets never reach it" {
  grep -qF '"--password-stdin", "--yes"' "$INST/WizState.qml"
  grep -qF '"sudo", "-n"' "$INST/WizState.qml"
  for f in --disk --user --hostname --tz --fs --swap --format-efi --alongside --erase --encrypt; do
    grep -qF "\"$f\"" "$INST/WizState.qml"
  done
  ! grep -rn 'password' "$INST/WizState.qml" | grep -iE 'argv|command' | grep -v stdin
  ! grep -rn 'sh", "-c' "$INST"
}

@test "no GTK remains in the tree" {
  ! grep -rn 'libadwaita\|gi.repository\|Gtk' "$ROOT/profile/airootfs/usr/local/bin/cyberos-install-gui" "$INST"
}

@test "WizState.argv builds sudo -n cyberos-install with mode args and secrets are isolated" {
  grep -q 'function argv()' "$INST/WizState.qml"
  grep -qF '"/usr/local/bin/cyberos-install"' "$INST/WizState.qml"
  grep -q 'function stdinSecrets()' "$INST/WizState.qml"
  # stdinSecrets is the only function referencing `password` or `luksPass`
  # for the purpose of building the secrets string (argv() must not).
  argv_body=$(awk '/function argv\(\)/,/^    }/' "$INST/WizState.qml" | sed 's/--password-stdin//g')
  ! grep -qE 'password|luksPass' <<<"$argv_body"
}

@test "ConfirmPage ports the summary lines and action text verbatim" {
  [ -f "$INST/pages/ConfirmPage.qml" ]
  grep -qF 'install alongside, using free space only' "$INST/pages/ConfirmPage.qml"
  grep -qF 'ERASE the whole disk' "$INST/pages/ConfirmPage.qml"
  grep -qF 'use the partitions chosen' "$INST/pages/ConfirmPage.qml"
  grep -qF 'I understand and want to continue' "$INST/pages/ConfirmPage.qml"
  grep -qF 'GiB swap' "$INST/pages/ConfirmPage.qml"
  grep -qF 'Install' "$INST/pages/ConfirmPage.qml"
}

@test "InstallPage streams output, handles dry-run and failure text verbatim" {
  [ -f "$INST/pages/InstallPage.qml" ]
  grep -qF 'DRY RUN' "$INST/pages/InstallPage.qml"
  grep -qF '(password supplied on stdin, not on the command line)' "$INST/pages/InstallPage.qml"
  grep -qF 'Installation FAILED with exit code' "$INST/pages/InstallPage.qml"
  grep -qF 'The error is in the output above.' "$INST/pages/InstallPage.qml"
  grep -q 'SplitParser' "$INST/pages/InstallPage.qml"
  grep -q 'stdinEnabled' "$INST/pages/InstallPage.qml"
  grep -qF 'WizState.stdinSecrets()' "$INST/pages/InstallPage.qml"
  ! grep -qF 'sh", "-c' "$INST/pages/InstallPage.qml"
}

@test "pages qmldir lists ConfirmPage and InstallPage" {
  grep -q 'ConfirmPage' "$INST/pages/qmldir"
  grep -q 'InstallPage' "$INST/pages/qmldir"
}
