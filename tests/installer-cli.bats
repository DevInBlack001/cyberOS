#!/usr/bin/env bats
# The GTK/QML installer wizards are gone (installer/cli-switch): cyberos-install-gui
# is now a 3-line foot(1) launcher around the ANSI CLI installer, and the CLI itself
# gained --dry-run and a 3-line --password-stdin protocol. These pin that contract.

ROOT="$BATS_TEST_DIRNAME/.."
GUI="$ROOT/profile/airootfs/usr/local/bin/cyberos-install-gui"
CLI="$ROOT/profile/airootfs/usr/local/bin/cyberos-install"
DESKTOP="$ROOT/profile/airootfs/usr/share/applications/cyberos-install.desktop"

@test "cyberos-install-gui is the foot launcher wrapper, not a GTK/QML shell" {
  run grep -c 'foot --app-id=cyberos-installer' "$GUI"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  run grep -c 'sudo /usr/local/bin/cyberos-install' "$GUI"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  # no leftover GTK/QML launch path
  run grep -E 'import gi|gi\.repository|qs -p' "$GUI"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "cyberos-install-gui forwards its own argv to the CLI" {
  run grep -F 'cyberos-install "$@"' "$GUI"
  [ "$status" -eq 0 ]
}

@test "cyberos-install.desktop launches the same foot/app-id wrapper" {
  run grep -c '^Exec=foot --app-id=cyberos-installer' "$DESKTOP"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
  run grep -F 'sudo /usr/local/bin/cyberos-install' "$DESKTOP"
  [ "$status" -eq 0 ]
}

@test "the desktop file's app-id matches the hyprland float/window rule" {
  # hyprland.lua's float-installer rule keys off class "^(cyberos-installer)$";
  # a mismatch here means the window never floats/centers.
  run grep -F 'app-id=cyberos-installer' "$DESKTOP"
  [ "$status" -eq 0 ]
  run grep -F 'cyberos-installer' "$ROOT/profile/airootfs/etc/skel/.config/hypr/hyprland.lua"
  [ "$status" -eq 0 ]
}

@test "the CLI advertises --dry-run" {
  run grep -c -- '--dry-run' "$CLI"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "--dry-run makes no changes and never reaches the chroot handoff" {
  run bash -c "sed -n '/DRY_RUN -eq 1/,/exit 0/p' '$CLI'"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No changes were made"* ]] || [[ "$output" == *"DRY RUN"* ]]
}

@test "--password-stdin reads exactly three lines: PASS, ROOTPASS, LUKSPASS" {
  run grep -n -- '--password-stdin' "$CLI"
  [ "$status" -eq 0 ]
  line=$(grep -- '--password-stdin)' "$CLI")
  [[ "$line" == *"read -r PASS"* ]]
  [[ "$line" == *"read -r ROOTPASS"* ]]
  [[ "$line" == *"read -r LUKSPASS"* ]]
}

@test "--password-stdin protocol matches the documented usage banner" {
  run grep -F 'line 3 of --password-stdin' "$CLI"
  [ "$status" -eq 0 ]
}

@test "a password supplied via --password-stdin never reaches argv/PASS_FROM_ARGV" {
  # Only --password (argv) sets PASS_FROM_ARGV=1; the stdin path must not.
  run grep -A1 -- '--password-stdin)' "$CLI"
  [ "$status" -eq 0 ]
  run bash -c "grep -A1 -- '--password-stdin)' '$CLI' | grep PASS_FROM_ARGV"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}
