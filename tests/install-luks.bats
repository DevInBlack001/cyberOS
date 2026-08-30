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

@test "busybox initrd: cryptdevice= on the kernel command line" {
  run luks_cmdline "dead-beef" "cryptroot" "base udev keyboard block encrypt filesystems"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cryptdevice=UUID=dead-beef:cryptroot"* ]]
  [[ "$output" == *"root=/dev/mapper/cryptroot"* ]]
}

# mkinitcpio 41 ships HOOKS=(base systemd ...). A systemd initrd ignores the
# busybox encrypt hook entirely -- build 14 timed out waiting for the mapper and
# dropped to emergency mode. The stock line, verbatim:
SYSD="base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck"

@test "systemd initrd: sd-encrypt is used, not encrypt" {
  run luks_hooks "$SYSD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"block sd-encrypt filesystems"* ]]
  ! [[ "$output" == *" encrypt "* ]]
}

@test "systemd initrd: rd.luks.name= on the kernel command line, not cryptdevice=" {
  run luks_cmdline "dead-beef" "cryptroot" "$SYSD"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rd.luks.name=dead-beef=cryptroot"* ]]
  [[ "$output" == *"root=/dev/mapper/cryptroot"* ]]
  ! [[ "$output" == *"cryptdevice"* ]]
}

@test "an existing sd-encrypt hook is not duplicated" {
  run luks_hooks "base systemd keyboard block sd-encrypt filesystems"
  [ "$(grep -o 'sd-encrypt' <<<"$output" | wc -l)" -eq 1 ]
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
  frag=$(luks_cmdline "dead-beef" cryptroot "$SYSD")
  run grub_safe_entries "1111-2222" "$frag"
  [ "$status" -eq 0 ]
  [[ "$output" == *"rd.luks.name=dead-beef=cryptroot"* ]]
  ! [[ "$output" == *"root=UUID=1111-2222"* ]]
}

@test "recovery entries still use the plain UUID when not encrypted" {
  run grub_safe_entries "1111-2222" ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"root=UUID=1111-2222"* ]]
}
