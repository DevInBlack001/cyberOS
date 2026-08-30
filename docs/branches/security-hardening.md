# Branch: `security/hardening`

**State:** planned · **Owner:** security owner · **Spec:** `docs/SPEC.md` §7
**Plan:** `docs/superpowers/plans/2026-08-30-hardware-security-baseline.md`

## Charter

A machine running Metasploit, Docker and a Wireshark capture on a campus network needs a
defensible baseline. Close the gaps the last audit found and keep the Lynis hardening index
moving in one direction.

Current index: **69** (was 66).

## Scope

| Path | Role |
|---|---|
| `profile/airootfs/etc/ssh/sshd_config.d/20-cyberos-hardening.conf` | SSH policy |
| `profile/airootfs/etc/ufw/` + installer | firewall |
| `profile/pacman.conf.in`, `profile/airootfs/etc/pacman.conf` | `SigLevel` |
| `profile/airootfs/usr/local/bin/cyberos-install` | LUKS2 |
| `profile/airootfs/etc/systemd/system/` | `arch-audit` timer |

## Required changes

| | Change | Why |
|---|---|---|
| S1 | `ufw` **enabled** on installed systems, `default deny incoming` | Currently installed but disabled, which protects nobody |
| S2 | `SigLevel = Required DatabaseRequired TrustedOnly` for `[cyberos*]` | `profile/pacman.conf.in` currently says `Optional TrustAll` |
| S3 | LUKS2 full-disk encryption in the installer | Student laptops get lost; they hold lab material |
| S4 | `arch-audit` + weekly timer | The security-backport route in §4.3 needs to know what is vulnerable |
| S5 | `sbctl` installed, key enrolment documented | Tier 2 machines with Secure Boot on are otherwise unbootable |
| S6 | Regression guard: the live session must not start `sshd` | The live user has no password |

## Deliberately rejected — do not "fix" these

- **`linux-hardened` as the default kernel.** Its ptrace and BPF restrictions break `gdb`,
  Ghidra and Metasploit, which are the point of the image. It MAY be an extra boot entry.
- **Removing Docker.** The socket is root-equivalent, and the course needs it. The
  mitigation is S1 plus not putting students in the `docker` group by default.

## Already satisfied — regression-guard these

- `PermitRootLogin no`, `PermitEmptyPasswords no`, replacing archiso's permissive
  `10-archiso.conf` which shipped `yes` for both while root and student had empty passwords.
- `sshd` is not enabled in the live image (verified).
- Passwords reach the installer over stdin, never `argv`.
- The installer deletes itself from the installed system.

## Advisories

CyberOS follows Arch's advisory stream via `arch-audit` and `security.archlinux.org` rather
than duplicating it. Write a `CSA-YYYY-NNN` note only when the vulnerability is
CyberOS-specific: our packages, our configs, our installer.
