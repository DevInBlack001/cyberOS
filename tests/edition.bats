#!/usr/bin/env bats

setup() {
  export BUILD_LIB_ONLY=1
  # shellcheck disable=SC1090
  source "$BATS_TEST_DIRNAME/../build.sh"
  TMP="$BATS_TEST_TMPDIR"
  printf '# base\nlinux\nhyprland\n'   >"$TMP/base"
  printf '# lab\nmetasploit\nghidra\n' >"$TMP/lab"
}

@test "base edition takes only the base list" {
  compose_packages base "$TMP/base" "$TMP/lab" "$TMP/out"
  grep -q '^hyprland$'     "$TMP/out"
  ! grep -q '^metasploit$' "$TMP/out"
}

@test "lab edition takes both lists" {
  compose_packages lab "$TMP/base" "$TMP/lab" "$TMP/out"
  grep -q '^hyprland$'   "$TMP/out"
  grep -q '^metasploit$' "$TMP/out"
}

@test "the generated list carries a do-not-edit warning" {
  compose_packages base "$TMP/base" "$TMP/lab" "$TMP/out"
  head -1 "$TMP/out" | grep -qi 'generated'
}

@test "an unknown edition is rejected" {
  run compose_packages student "$TMP/base" "$TMP/lab" "$TMP/out"
  [ "$status" -ne 0 ]
}

@test "assert_iso_size fails a base image over budget" {
  head -c 100 /dev/zero >"$TMP/big.iso"
  run assert_iso_size "$TMP/big.iso" 50
  [ "$status" -ne 0 ]
  [[ "$output" == *"budget"* ]]
}

@test "assert_iso_size passes an image under budget" {
  head -c 100 /dev/zero >"$TMP/ok.iso"
  run assert_iso_size "$TMP/ok.iso" 200
  [ "$status" -eq 0 ]
}

@test "sourcing build.sh in library mode runs no build" {
  run bash -c "BUILD_LIB_ONLY=1 source '$BATS_TEST_DIRNAME/../build.sh'; echo SOURCED-OK"
  [ "$status" -eq 0 ]
  [[ "$output" == *"SOURCED-OK"* ]]
  ! [[ "$output" == *"mkarchiso"* ]]
}
