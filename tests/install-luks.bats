#!/usr/bin/env bats

setup() {
  export CYBEROS_INSTALL_LIB_ONLY=1
  # shellcheck disable=SC1090
  source "$BATS_TEST_DIRNAME/../profile/airootfs/usr/local/bin/cyberos-install"
}

@test "encrypt goes after block and before filesystems" {
  run luks_hooks "base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck"
  [ "$status" -eq 0 ]
  [[ "$output" == *"block encrypt filesystems"* ]]
}

@test "encrypt is not added twice" {
  run luks_hooks "base udev keyboard block encrypt filesystems fsck"
  [ "$status" -eq 0 ]
  [ "$(grep -o encrypt <<<"$output" | wc -l)" -eq 1 ]
}

@test "keyboard must already be present, or it fails loudly" {
  run luks_hooks "base udev block filesystems fsck"
  [ "$status" -ne 0 ]
  [[ "$output" == *"keyboard"* ]]
}

@test "a missing block hook is refused rather than guessed at" {
  run luks_hooks "base udev keyboard filesystems fsck"
  [ "$status" -ne 0 ]
  [[ "$output" == *"block"* ]]
}

@test "the kernel command line names the LUKS device and the mapper" {
  run luks_cmdline "dead-beef" "cryptroot"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cryptdevice=UUID=dead-beef:cryptroot"* ]]
  [[ "$output" == *"root=/dev/mapper/cryptroot"* ]]
}

@test "luks_cmdline refuses an empty UUID" {
  run luks_cmdline "" cryptroot
  [ "$status" -ne 0 ]
}

@test "the installer advertises --encrypt" {
  run grep -c -- '--encrypt' "$BATS_TEST_DIRNAME/../profile/airootfs/usr/local/bin/cyberos-install"
  [ "$output" -gt 0 ]
}

@test "recovery entries use the mapper, not a bare UUID, on an encrypted root" {
  frag=$(luks_cmdline "dead-beef" cryptroot)
  run grub_safe_entries "1111-2222" "$frag"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cryptdevice=UUID=dead-beef:cryptroot"* ]]
  ! [[ "$output" == *"root=UUID=1111-2222"* ]]
}

@test "recovery entries still use the plain UUID when not encrypted" {
  run grub_safe_entries "1111-2222" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"root=UUID=1111-2222"* ]]
}
