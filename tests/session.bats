#!/usr/bin/env bats

setup() {
  # shellcheck disable=SC1090
  source "$BATS_TEST_DIRNAME/../profile/airootfs/usr/local/bin/cyberos-session"
}

@test "safe graphics is off for a normal command line" {
  run safe_graphics_requested "BOOT_IMAGE=/vmlinuz-linux root=UUID=abc rw quiet"
  [ "$status" -ne 0 ]
}

@test "safe graphics is on when the token is present" {
  run safe_graphics_requested "BOOT_IMAGE=/vmlinuz-linux root=UUID=abc rw nomodeset cyberos.safegraphics=1"
  [ "$status" -eq 0 ]
}

@test "a token that merely contains the name does not count" {
  run safe_graphics_requested "root=UUID=abc notcyberos.safegraphics_extra=1"
  [ "$status" -ne 0 ]
}

@test "normal mode exports nothing" {
  run session_env "root=UUID=abc rw quiet"
  [ "$output" = "" ]
}

@test "safe mode forces software rendering for both wlroots and GL" {
  run session_env "root=UUID=abc cyberos.safegraphics=1"
  [[ "$output" == *"WLR_RENDERER_ALLOW_SOFTWARE=1"* ]]
  [[ "$output" == *"LIBGL_ALWAYS_SOFTWARE=1"* ]]
}

@test "the session execs start-hyprland, not Hyprland directly" {
  # exec Hyprland directly makes it print a "started without start-hyprland"
  # warning banner on every login. Seen on build 15 on real hardware.
  grep -q 'exec /usr/bin/start-hyprland' "$BATS_TEST_DIRNAME/../profile/airootfs/usr/local/bin/cyberos-session"
  ! grep -qE '^\s*exec Hyprland' "$BATS_TEST_DIRNAME/../profile/airootfs/usr/local/bin/cyberos-session"
}
