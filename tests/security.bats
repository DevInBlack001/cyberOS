#!/usr/bin/env bats

setup() {
  export CYBEROS_INSTALL_LIB_ONLY=1
  # shellcheck disable=SC1090
  source "$BATS_TEST_DIRNAME/../profile/airootfs/usr/local/bin/cyberos-install"
  ROOT="$BATS_TEST_DIRNAME/.."
}

@test "the firewall defaults to deny incoming" {
  run firewall_rules
  [[ "$output" == *"default deny incoming"* ]]
  [[ "$output" == *"default allow outgoing"* ]]
  [[ "$output" == *"enable"* ]]
}

@test "the firewall does not open any port by default" {
  run firewall_rules
  # merged into one condition (sole/last statement) -- a mid-body "!" is
  # exempt from errexit and would be silently swallowed by the later check.
  ! [[ "$output" == *"allow 22"* || "$output" == *"allow ssh"* ]]
}

@test "sshd is not enabled in the live image" {
  run assert_no_sshd_in_live "$ROOT/profile/airootfs"
  [ "$status" -eq 0 ]
}

@test "the guard notices an sshd symlink if one is added" {
  tmp="$BATS_TEST_TMPDIR/airootfs"
  mkdir -p "$tmp/etc/systemd/system/multi-user.target.wants"
  ln -s ../sshd.service "$tmp/etc/systemd/system/multi-user.target.wants/sshd.service"
  run assert_no_sshd_in_live "$tmp"
  [ "$status" -ne 0 ]
  [[ "$output" == *"sshd"* ]]
}

@test "the installed system never trusts an unsigned repository" {
  # This is the config students' machines fetch over a network. The build-time
  # config is a different threat model: a local directory this same script wrote
  # seconds earlier on this same machine.
  run grep -n 'TrustAll' "$ROOT/profile/airootfs/etc/pacman.conf"
  [ "$status" -ne 0 ]
}

@test "the installed system does not fetch packages over plain http" {
  run grep -nE '^#?Server *= *http://' "$ROOT/profile/airootfs/etc/pacman.conf"
  [ "$status" -ne 0 ]
}

@test "SSH hardening is still in place" {
  conf="$ROOT/profile/airootfs/etc/ssh/sshd_config.d/20-cyberos-hardening.conf"
  grep -qE '^PermitRootLogin +no'      "$conf"
  grep -qE '^PermitEmptyPasswords +no' "$conf"
}

@test "first boot never resets ufw (it deletes the shipped rules under a starting service)" {
  # run-wrapped: a mid-body "!" is exempt from errexit and would be silently
  # swallowed by the "run firewall_rules" that follows.
  run grep -qE '^\s*ufw (--force )?reset' "$ROOT/profile/airootfs/usr/local/bin/cyberos-firstboot"
  [ "$status" -ne 0 ]
  run firewall_rules
  ! [[ "$output" == *"reset"* ]]
}

@test "arch-audit runs on a weekly timer, enabled on install (docs/SPEC.md S4)" {
  [ -f "$ROOT/profile/airootfs/etc/systemd/system/cyberos-arch-audit.service" ]
  [ -f "$ROOT/profile/airootfs/etc/systemd/system/cyberos-arch-audit.timer" ]
  grep -qE '^OnCalendar=weekly' "$ROOT/profile/airootfs/etc/systemd/system/cyberos-arch-audit.timer"
  grep -q '^ExecStart=/usr/bin/arch-audit' "$ROOT/profile/airootfs/etc/systemd/system/cyberos-arch-audit.service"
  grep -q '^arch-audit$' "$ROOT/profile/packages.x86_64"
  grep -q 'cyberos-arch-audit.timer' "$ROOT/profile/airootfs/usr/local/bin/cyberos-install"
}

@test "--user/--password/--root-password cannot inject shell syntax into the chroot handoff" {
  # A crafted --user (or --password) containing a quote/backtick/$(...) used to
  # become literal shell syntax inside arch-chroot's bash, because the heredoc
  # that hands the installer's state to the chroot was unquoted and expanded
  # by the host shell. Two independent guards now cover this: the heredoc is
  # quoted (tested in install-boot.bats), and valid_username rejects anything
  # outside useradd's own character set before it gets that far.
  run valid_username 'x"; touch /tmp/PWNED; echo "'
  [ "$status" -ne 0 ]
}
