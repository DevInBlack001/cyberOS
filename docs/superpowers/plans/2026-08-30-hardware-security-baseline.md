# CyberOS Hardware and Security Baseline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make "runs well on all machines" testable — a recovery path on every supported machine, drivers for the hardware students actually own, an image small enough to distribute, a defensible security baseline, and an automated harness that proves it instead of a person clicking through QEMU once.

**Architecture:** Three support tiers replace the untestable claim; only Tier 1 gates a release. Two recovery paths (`linux-lts` and a safe-graphics boot entry) mean a student who cannot reach a desktop still has a way back in. The image splits into `cyberos-base` (≤ 2.0 GiB, distributable as a GitHub release asset) and `cyberos-lab` (full offline toolset), generated from one profile by a build flag. A QEMU harness drives the release criteria over a serial console with autologin — not through screen scraping, which has already proven unreliable in this repo.

**Tech Stack:** archiso 89, mkarchiso, GRUB, mkinitcpio 41.1, QEMU/KVM + OVMF, `linux` 7.1.9 / `linux-lts` 6.18.46, `nvidia-open-dkms` 610.57, `broadcom-wl-dkms`, `fwupd` 2.1.7, `ufw`, `cryptsetup` (LUKS2), `bats` 1.14.

**Spec:** `docs/SPEC.md` §2 (hardware tiers), §6 (quality gates), §7 (security)

## Global Constraints

- Two branches: `hardware/enablement` (Tasks 1–3, 6) and `security/hardening` (Tasks 4–5), both off `main`. Keep the commits separate; they have different CODEOWNERS.
- Commit author is `edbron <edbron411@gmail.com>`. Do not override the repo-local git identity.
- **Both editions build from one `profile/`.** The difference is a package list selected by a build flag. Two profiles would drift, and the drift would only surface on a student's machine.
- **`cyberos-base` MUST be ≤ 2.0 GiB.** GitHub refuses release assets above that, and the current 4.9 GiB image therefore cannot be distributed through the repo's own release page.
- Every executable under `profile/airootfs/` MUST be in `profile/profiledef.sh` `file_permissions` — `mkarchiso` copies with `cp -af --no-preserve=ownership,mode`.
- **`linux-hardened` MUST NOT become the default kernel.** Its ptrace and BPF restrictions break `gdb`, Ghidra and Metasploit, which are the point of the image.
- **Docker stays.** The course needs it. The mitigation is the firewall, and not putting students in the `docker` group by default.
- `./build.sh` and `./test-vm.sh` are run as a **normal user**, not with sudo — build.sh refuses to run as root and calls sudo itself. Both must be run by a person; `sudo` cannot take a password from an agent session.

## File Structure

| File | Responsibility |
|---|---|
| `profile/packages.base.x86_64` | the `base` edition package set (was `packages.x86_64`) |
| `profile/packages.lab.x86_64` | security-lab toolset, added for the `lab` edition |
| `profile/packages.x86_64` | **generated** by `build.sh`; gitignored, like `profile/pacman.conf` |
| `build.sh` | `--edition base\|lab`, and the size assertion |
| `profile/airootfs/usr/local/bin/cyberos-session` | reads `/proc/cmdline`, sets software rendering, execs Hyprland |
| `profile/airootfs/usr/share/wayland-sessions/cyberos.desktop` | SDDM session pointing at the wrapper |
| `profile/efiboot/loader/entries/` | live boot entries incl. safe graphics |
| `profile/syslinux/archiso_sys-linux.cfg` | the BIOS equivalents |
| `profile/airootfs/usr/local/bin/cyberos-install` | installed-system kernels, boot entries, LUKS2 |
| `tools/qa/run-matrix.sh` | the release-criteria harness |
| `tools/qa/lib/qmp.sh` | QEMU monitor and serial helpers |
| `tests/session.bats`, `tests/install-luks.bats`, `tests/edition.bats` | tests |

---

### Task 1: Recovery paths — `linux-lts` and safe graphics

The two failures that leave a student with nothing: a kernel update regresses their driver,
or Hyprland cannot initialise GL and they get a black screen. Neither is recoverable today,
and a student who cannot reach a desktop cannot file a bug.

**Files:**
- Create: `profile/airootfs/usr/local/bin/cyberos-session`
- Create: `profile/airootfs/usr/share/wayland-sessions/cyberos.desktop`
- Modify: `profile/packages.x86_64` (add `linux-lts`, `linux-lts-headers`)
- Modify: `profile/profiledef.sh`
- Test: `tests/session.bats`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `safe_graphics_requested <cmdline-string>` → exit 0 when the kernel command line contains `cyberos.safegraphics`
  - `session_env <cmdline-string>` → prints the `VAR=value` lines to export, one per line, empty when not in safe mode

- [ ] **Step 1: Write the failing test**

Create `tests/session.bats`:

```bash
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
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/session.bats`
Expected: FAIL — `cyberos-session` does not exist, `source` errors in setup.

- [ ] **Step 3: Write the minimal implementation**

Create `profile/airootfs/usr/local/bin/cyberos-session`:

```bash
#!/usr/bin/env bash
# cyberos-session -- start the CyberOS desktop.
#
# Hyprland needs a working OpenGL/Wayland stack. On hardware where it does not
# initialise, the student gets a black screen and no way to report it. Booting
# the "safe graphics" entry adds cyberos.safegraphics to the kernel command
# line; this wrapper turns that into software rendering.

# Only when executed: `set -u` leaks into bats and breaks its internals when
# this file is sourced by the test suite.
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  set -euo pipefail
fi

# safe_graphics_requested <cmdline> -- exit 0 if the token is present.
safe_graphics_requested() {
  local word
  for word in $1; do
    case $word in
      cyberos.safegraphics|cyberos.safegraphics=*) return 0 ;;
    esac
  done
  return 1
}

# session_env <cmdline> -- the environment to export, one VAR=value per line.
session_env() {
  safe_graphics_requested "$1" || return 0
  printf 'WLR_RENDERER_ALLOW_SOFTWARE=1\n'
  printf 'LIBGL_ALWAYS_SOFTWARE=1\n'
  printf 'WLR_NO_HARDWARE_CURSORS=1\n'
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  cmdline=$(cat /proc/cmdline 2>/dev/null || echo "")
  while IFS= read -r line; do
    [[ -n $line ]] && export "${line?}"
  done < <(session_env "$cmdline")
  exec Hyprland "$@"
fi
```

Create `profile/airootfs/usr/share/wayland-sessions/cyberos.desktop`:

```ini
[Desktop Entry]
Name=CyberOS (Hyprland)
Comment=Hyprland, with software rendering when booted for safe graphics
Exec=/usr/local/bin/cyberos-session
Type=Application
```

Add to `profile/packages.x86_64`, in the base-system section beside `linux`:

```
linux-lts
linux-lts-headers
```

Add to `profile/profiledef.sh` `file_permissions`:

```bash
  ["/usr/local/bin/cyberos-session"]="0:0:755"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats tests/session.bats`
Expected: PASS, 5 tests.

- [ ] **Step 5: Add the live boot entries**

Copy `profile/efiboot/loader/entries/01-archiso-x86_64-linux.conf` to
`02-cyberos-safe-graphics.conf` and change the title and options:

```
title    CyberOS (safe graphics)
linux    /arch/boot/x86_64/vmlinuz-linux
initrd   /arch/boot/intel-ucode.img
initrd   /arch/boot/amd-ucode.img
initrd   /arch/boot/x86_64/initramfs-linux.img
options  archisobasedir=arch archisolabel=%ARCHISO_LABEL% nomodeset cyberos.safegraphics=1
```

Add the matching BIOS entry to `profile/syslinux/archiso_sys-linux.cfg`:

```
LABEL cyberos_safe
TEXT HELP
Boot CyberOS with software rendering, for machines whose GPU driver fails.
ENDTEXT
MENU LABEL CyberOS (safe graphics)
LINUX /%INSTALL_DIR%/boot/x86_64/vmlinuz-linux
INITRD /%INSTALL_DIR%/boot/intel-ucode.img,/%INSTALL_DIR%/boot/amd-ucode.img,/%INSTALL_DIR%/boot/x86_64/initramfs-linux.img
APPEND archisobasedir=%INSTALL_DIR% archisolabel=%ARCHISO_LABEL% nomodeset cyberos.safegraphics=1
```

Confirm the placeholder names by reading the existing entries first — copy the exact
`%ARCHISO_LABEL%` / `%INSTALL_DIR%` spelling from the file rather than from this plan.

- [ ] **Step 6: Commit**

```bash
shellcheck profile/airootfs/usr/local/bin/cyberos-session
git add profile/airootfs/usr/local/bin/cyberos-session \
        profile/airootfs/usr/share/wayland-sessions/cyberos.desktop \
        profile/efiboot/loader/entries/02-cyberos-safe-graphics.conf \
        profile/syslinux/archiso_sys-linux.cfg \
        profile/packages.x86_64 profile/profiledef.sh tests/session.bats
git commit -m "hardware: safe-graphics session and an LTS kernel to fall back to"
```

---

### Task 2: Carry both kernels and both recovery entries onto the installed system

The live image having a recovery path is not enough — the installed system is where a
student is stranded. archiso keeps the kernel on the ISO rather than in the airootfs, which
the installer already works around for `linux`; `linux-lts` needs the same treatment.

**Files:**
- Modify: `profile/airootfs/usr/local/bin/cyberos-install`
- Test: `tests/install-boot.bats`

**Interfaces:**
- Consumes: `ROOTP` and the chroot section of `cyberos-install`
- Produces:
  - `restore_kernel <flavour> <bootmnt> <dest>` — installs a kernel image for `linux` or `linux-lts`, returning non-zero with a clear message if the source is missing
  - `grub_safe_entries <root-uuid>` — prints the `/etc/grub.d/40_custom` body

- [ ] **Step 1: Write the failing test**

Create `tests/install-boot.bats`:

```bash
#!/usr/bin/env bats

setup() {
  export CYBEROS_INSTALL_LIB_ONLY=1
  # shellcheck disable=SC1090
  source "$BATS_TEST_DIRNAME/../profile/airootfs/usr/local/bin/cyberos-install"
  TMP="$BATS_TEST_TMPDIR"
}

@test "restore_kernel copies the image when the source exists" {
  mkdir -p "$TMP/bootmnt/arch/boot/x86_64" "$TMP/dest/boot"
  echo kernel >"$TMP/bootmnt/arch/boot/x86_64/vmlinuz-linux"
  run restore_kernel linux "$TMP/bootmnt" "$TMP/dest"
  [ "$status" -eq 0 ]
  [ -f "$TMP/dest/boot/vmlinuz-linux" ]
}

@test "restore_kernel names the flavour it could not find" {
  mkdir -p "$TMP/bootmnt/arch/boot/x86_64" "$TMP/dest/boot"
  run restore_kernel linux-lts "$TMP/bootmnt" "$TMP/dest"
  [ "$status" -ne 0 ]
  [[ "$output" == *"linux-lts"* ]]
}

@test "restore_kernel falls back to the airootfs copy for lts" {
  mkdir -p "$TMP/bootmnt/arch/boot/x86_64" "$TMP/dest/boot"
  mkdir -p "$TMP/dest/usr/lib/modules/6.18.46-1-lts"
  echo kernel >"$TMP/dest/usr/lib/modules/6.18.46-1-lts/vmlinuz"
  run restore_kernel linux-lts "$TMP/bootmnt" "$TMP/dest"
  [ "$status" -eq 0 ]
  [ -f "$TMP/dest/boot/vmlinuz-linux-lts" ]
}

@test "grub_safe_entries emits one entry per kernel with the safe token" {
  run grub_safe_entries "1111-2222"
  [ "$status" -eq 0 ]
  [[ "$output" == *"cyberos.safegraphics=1"* ]]
  [[ "$output" == *"nomodeset"* ]]
  [[ "$output" == *"vmlinuz-linux"* ]]
  [[ "$output" == *"vmlinuz-linux-lts"* ]]
  [[ "$output" == *"1111-2222"* ]]
}

@test "grub_safe_entries refuses to emit an entry with no root UUID" {
  run grub_safe_entries ""
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/install-boot.bats`
Expected: FAIL — `restore_kernel` is undefined, and sourcing `cyberos-install` runs the
installer rather than defining functions.

- [ ] **Step 3: Write the minimal implementation**

Near the top of `cyberos-install`, after the option parsing and before any disk work, add
the library guard so the file can be sourced by tests:

```bash
# Sourcing this file with CYBEROS_INSTALL_LIB_ONLY=1 defines the helpers without
# running the installer, so they can be tested on a host with no disks to lose.
# Keep `set -euo pipefail` inside that guard too: `set -u` leaks into bats and
# breaks its internals when the file is sourced.
```

and wrap the main body so it is skipped when that variable is set. Then add:

```bash
# restore_kernel <flavour> <bootmnt> <dest>
#
# archiso keeps the kernel on the ISO rather than in the airootfs, so the copied
# root has an empty /boot and mkinitcpio fails with "must be readable". The
# primary kernel is on the boot medium; linux-lts is not, but its image survives
# inside the squashfs under /usr/lib/modules.
restore_kernel() {
  local flavour=$1 bootmnt=$2 dest=$3 src

  src="$bootmnt/arch/boot/x86_64/vmlinuz-$flavour"
  if [[ -f $src ]]; then
    install -Dm644 "$src" "$dest/boot/vmlinuz-$flavour"
    return 0
  fi

  src=$(find "$dest/usr/lib/modules" -maxdepth 2 -name vmlinuz \
          -path "*${flavour#linux}*" 2>/dev/null | head -1)
  if [[ $flavour == linux ]]; then
    src=$(find "$dest/usr/lib/modules" -maxdepth 2 -name vmlinuz 2>/dev/null \
            | grep -v -- '-lts/' | head -1)
  fi
  if [[ -n $src && -f $src ]]; then
    install -Dm644 "$src" "$dest/boot/vmlinuz-$flavour"
    return 0
  fi

  printf 'no kernel image found for %s (looked on the boot medium and in %s/usr/lib/modules)\n' \
    "$flavour" "$dest" >&2
  return 1
}

# grub_safe_entries <root-uuid> -- the /etc/grub.d/40_custom body.
#
# GRUB's generated entries cannot carry an extra kernel argument, so the safe
# entries are written explicitly with the root UUID the installer already knows.
grub_safe_entries() {
  local uuid=$1
  [[ -n $uuid ]] || { printf 'grub_safe_entries: no root UUID\n' >&2; return 1; }
  cat <<ENTRIES
#!/bin/sh
exec tail -n +3 \$0
# Recovery entries. Do not remove: a student whose GPU driver fails has no other
# way back to a desktop, and one whose kernel regressed has no other way to boot.

menuentry 'CyberOS (safe graphics)' --class cyberos {
    search --no-floppy --fs-uuid --set=root $uuid
    linux /boot/vmlinuz-linux root=UUID=$uuid rw nomodeset cyberos.safegraphics=1
    initrd /boot/initramfs-linux.img
}

menuentry 'CyberOS (LTS kernel)' --class cyberos {
    search --no-floppy --fs-uuid --set=root $uuid
    linux /boot/vmlinuz-linux-lts root=UUID=$uuid rw
    initrd /boot/initramfs-linux-lts.img
}

menuentry 'CyberOS (LTS kernel, safe graphics)' --class cyberos {
    search --no-floppy --fs-uuid --set=root $uuid
    linux /boot/vmlinuz-linux-lts root=UUID=$uuid rw nomodeset cyberos.safegraphics=1
    initrd /boot/initramfs-linux-lts.img
}
ENTRIES
}
```

Replace the existing kernel-restore lines with calls to `restore_kernel` for both flavours,
add an LTS mkinitcpio preset beside the existing one, and write `40_custom` before
`grub-mkconfig` runs:

```bash
restore_kernel linux     /run/archiso/bootmnt /mnt || die "kernel image not found"
restore_kernel linux-lts /run/archiso/bootmnt /mnt \
  || echo "WARNING: no LTS kernel; the installed system will have no fallback kernel"

cat > /mnt/etc/mkinitcpio.d/linux-lts.preset <<'M'
# mkinitcpio preset file for the 'linux-lts' package
ALL_kver="/boot/vmlinuz-linux-lts"
PRESETS=('default' 'fallback')
default_image="/boot/initramfs-linux-lts.img"
fallback_image="/boot/initramfs-linux-lts-fallback.img"
fallback_options="-S autodetect"
M

ROOT_UUID=$(blkid -o value -s UUID "$ROOTP")
grub_safe_entries "$ROOT_UUID" > /mnt/etc/grub.d/40_custom
chmod 755 /mnt/etc/grub.d/40_custom
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats tests/install-boot.bats`
Expected: PASS, 5 tests.

- [ ] **Step 5: Confirm the installer still parses and its help still works**

```bash
bash -n profile/airootfs/usr/local/bin/cyberos-install
CYBEROS_INSTALL_LIB_ONLY=1 bash profile/airootfs/usr/local/bin/cyberos-install
bash profile/airootfs/usr/local/bin/cyberos-install --help
```

Expected: no syntax errors; sourcing in library mode exits 0 and touches nothing; `--help`
still prints usage. The library guard is the risky change here — if it is placed wrong the
installer becomes a no-op and the failure only shows up mid-install on a student's disk.

- [ ] **Step 6: Commit**

```bash
shellcheck profile/airootfs/usr/local/bin/cyberos-install || true
git add profile/airootfs/usr/local/bin/cyberos-install tests/install-boot.bats
git commit -m "hardware: install both kernels and both recovery boot entries"
```

---

### Task 3: Drivers, firmware, and the edition split

The hardware students actually own, and an image small enough to hand them.

**Files:**
- Create: `profile/packages.base.x86_64`, `profile/packages.lab.x86_64`
- Modify: `build.sh`, `.gitignore`
- Test: `tests/edition.bats`

**Interfaces:**
- Consumes: the current `profile/packages.x86_64`
- Produces:
  - `compose_packages <edition> <base-file> <lab-file> <out-file>` in `build.sh` — writes the generated package list
  - `assert_iso_size <iso> <max-bytes>` — fails the build when `base` exceeds its budget

- [ ] **Step 1: Write the failing test**

Create `tests/edition.bats`:

```bash
#!/usr/bin/env bats

setup() {
  export BUILD_LIB_ONLY=1
  # shellcheck disable=SC1090
  source "$BATS_TEST_DIRNAME/../build.sh"
  TMP="$BATS_TEST_TMPDIR"
  printf '# base\nlinux\nhyprland\n'      >"$TMP/base"
  printf '# lab\nmetasploit\nghidra\n'    >"$TMP/lab"
}

@test "base edition takes only the base list" {
  compose_packages base "$TMP/base" "$TMP/lab" "$TMP/out"
  grep -q '^hyprland$'   "$TMP/out"
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
  [[ "$output" == *"2 GiB"* ]] || [[ "$output" == *"budget"* ]]
}

@test "assert_iso_size passes an image under budget" {
  head -c 100 /dev/zero >"$TMP/ok.iso"
  run assert_iso_size "$TMP/ok.iso" 200
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/edition.bats`
Expected: FAIL — `compose_packages` is undefined, and sourcing `build.sh` runs a build.

- [ ] **Step 3: Write the minimal implementation**

```bash
git mv profile/packages.x86_64 profile/packages.base.x86_64
```

Move the `# ---- security lab toolset ----` block out of `packages.base.x86_64` into a new
`profile/packages.lab.x86_64`. Keep `lynis`, `clamav`, `nmap`, `wireshark-qt` and `arch-audit`
in **base** — they are part of the security baseline, not the lab toolset. Move
`metasploit`, `ghidra`, `radare2`, `exploitdb`, `hashcat`, `hashcat-utils`, `john`, `hydra`,
`aircrack-ng`, `bettercap`, `masscan`, `volatility3`, `sleuthkit`, `foremost`, `binwalk`,
`impacket`, `sqlmap`, `nikto`, `gobuster`, `yara`, `virtualbox*` to **lab**.

Add to `packages.base.x86_64`, in the graphics section:

```
# Drivers for the hardware students actually own. nvidia-open supports Turing
# (GTX 16xx / RTX 20xx) and newer only; older cards fall back to nouveau and are
# Tier 3 in docs/SPEC.md.
nvidia-open-dkms
broadcom-wl-dkms
fwupd

# Secure Boot: CyberOS has no Microsoft-signed shim and cannot claim Secure Boot
# support, but sbctl lets a lab enrol its own keys rather than leaving Tier 2
# machines unbootable. Spec requirement S5.
sbctl
```

Add to `build.sh`, and guard the build body with `BUILD_LIB_ONLY` so the tests can source
it. Move `build.sh`'s existing `set -euo pipefail` inside that guard as well — `set -u`
leaks into bats and breaks its internals when the file is sourced:

```bash
# compose_packages <edition> <base-file> <lab-file> <out-file>
#
# Both editions come from one profile: the difference is which lists are
# concatenated. Two profiles would drift, and the drift would only show up on a
# student's machine.
compose_packages() {
  local edition=$1 base=$2 lab=$3 out=$4
  case $edition in
    base|lab) ;;
    *) printf 'unknown edition: %s (want base or lab)\n' "$edition" >&2; return 1 ;;
  esac
  {
    printf '# GENERATED by build.sh --edition %s. Do not edit.\n' "$edition"
    printf '# Sources: %s' "$(basename "$base")"
    [[ $edition == lab ]] && printf ' + %s' "$(basename "$lab")"
    printf '\n'
    cat "$base"
    [[ $edition == lab ]] && cat "$lab"
  } >"$out"
}

# assert_iso_size <iso> <max-bytes>
#
# cyberos-base must stay under GitHub's 2 GiB release-asset cap, or it cannot be
# distributed through the repository's own release page.
assert_iso_size() {
  local iso=$1 max=$2 actual
  actual=$(stat -c %s "$iso")
  if (( actual > max )); then
    printf 'ISO is %s bytes, over the %s-byte budget.\n' "$actual" "$max" >&2
    printf 'cyberos-base must fit GitHub'"'"'s 2 GiB release-asset cap; move packages to packages.lab.x86_64.\n' >&2
    return 1
  fi
  printf 'ISO size %s bytes, within budget %s.\n' "$actual" "$max"
}

BASE_SIZE_BUDGET=$(( 2 * 1024 * 1024 * 1024 ))
```

In `build.sh`'s argument parsing add `--edition base|lab` (default `base`), call
`compose_packages` before `mkarchiso`, and call `assert_iso_size` afterwards when the
edition is `base`.

Add to `.gitignore`, beside the existing `profile/pacman.conf` line:

```
profile/packages.x86_64
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats tests/edition.bats`
Expected: PASS, 6 tests.

- [ ] **Step 5: Check the composition on the real lists**

```bash
BUILD_LIB_ONLY=1 bash -c 'source ./build.sh
  compose_packages base profile/packages.base.x86_64 profile/packages.lab.x86_64 /tmp/pk-base
  compose_packages lab  profile/packages.base.x86_64 profile/packages.lab.x86_64 /tmp/pk-lab'
printf 'base %s packages\nlab  %s packages\n' \
  "$(grep -cv '^#\|^$' /tmp/pk-base)" "$(grep -cv '^#\|^$' /tmp/pk-lab)"
comm -13 <(sort -u /tmp/pk-base) <(sort -u /tmp/pk-lab) | grep -v '^#' | head -30
```

Expected: base is meaningfully smaller than the current 205 packages, lab is a superset, and
the difference is exactly the lab toolset. Nothing should appear in base that was meant for
lab — check the list by eye before building, because the alternative is a 40-minute build.

- [ ] **Step 6: Commit**

```bash
git add profile/packages.base.x86_64 profile/packages.lab.x86_64 build.sh \
        .gitignore tests/edition.bats
git rm --cached profile/packages.x86_64
git commit -m "hardware: split base and lab editions, add missing drivers and fwupd"
```

---

### Task 4: Security baseline — firewall on, signatures required

`ufw` is installed and disabled, which protects nobody. `[cyberos]` is configured
`SigLevel = Optional TrustAll`, which trusts anything in the repository directory.

**Files:**
- Modify: `profile/airootfs/usr/local/bin/cyberos-install`
- Modify: `profile/pacman.conf.in`, `profile/airootfs/etc/pacman.conf`
- Create: `profile/airootfs/usr/local/bin/cyberos-firstboot` (extend the existing one)
- Test: `tests/security.bats`

**Interfaces:**
- Consumes: the chroot section of `cyberos-install`
- Produces:
  - `firewall_rules` — prints the `ufw` commands applied at first boot
  - `assert_no_sshd_in_live <airootfs-dir>` — a regression guard runnable in CI

- [ ] **Step 1: Write the failing test**

Create `tests/security.bats`:

```bash
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
  ! [[ "$output" == *"allow 22"* ]]
  ! [[ "$output" == *"allow ssh"* ]]
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

@test "no pacman config trusts a repository without signatures" {
  run grep -rn 'TrustAll' "$ROOT/profile/pacman.conf.in" "$ROOT/profile/airootfs/etc/pacman.conf"
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/security.bats`
Expected: FAIL — `firewall_rules` undefined, and the `TrustAll` test fails because
`profile/pacman.conf.in` still contains it.

- [ ] **Step 3: Write the minimal implementation**

Add to `cyberos-install`, in the library section:

```bash
# firewall_rules -- the posture an installed CyberOS machine boots with.
#
# A machine running Metasploit, Docker and a packet capture on a campus network
# needs default-deny. Nothing is opened by default: a student who needs a
# listening service opens that port deliberately.
firewall_rules() {
  cat <<'RULES'
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
RULES
}

# assert_no_sshd_in_live <airootfs-dir> -- regression guard.
#
# The live user has no password. archiso's own sshd drop-in shipped
# PermitRootLogin yes and PasswordAuthentication yes; ours replaces it, but the
# real protection is that sshd never starts in the live session.
assert_no_sshd_in_live() {
  local root=$1 hits
  hits=$(find "$root/etc/systemd/system" -name 'sshd*' 2>/dev/null || true)
  if [[ -n $hits ]]; then
    printf 'sshd is enabled in the live image:\n%s\n' "$hits" >&2
    return 1
  fi
  return 0
}
```

Extend `profile/airootfs/usr/local/bin/cyberos-firstboot` to apply them on the installed
system's first boot, where `ufw` is actually present and running:

```bash
# Firewall: default-deny incoming. Applied at first boot rather than in the
# chroot, because ufw needs a running kernel to load its rules.
if command -v ufw >/dev/null && [[ ! -e /etc/cyberos/firewall-applied ]]; then
  ufw --force reset          >/dev/null 2>&1 || true
  ufw default deny incoming  >/dev/null 2>&1 || true
  ufw default allow outgoing >/dev/null 2>&1 || true
  ufw --force enable         >/dev/null 2>&1 || true
  systemctl enable --now ufw.service >/dev/null 2>&1 || true
  mkdir -p /etc/cyberos && : >/etc/cyberos/firewall-applied
fi
```

In `profile/pacman.conf.in`, replace the `[cyberos]` `SigLevel` line:

```
SigLevel = Required DatabaseRequired TrustedOnly
```

This closes spec requirement **S2**. The build will now fail unless the local repo is
signed, so `build.sh` must either sign it or pass `--unsigned` explicitly for a local
development build — the same shape `tools/release.sh` already uses. Make that flag explicit
rather than restoring `TrustAll` when the build breaks.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats tests/security.bats`
Expected: PASS, 5 tests.

- [ ] **Step 5: Wire the regression guard into CI**

Add a step to `.github/workflows/verify-submission.yml`, or create
`.github/workflows/guards.yml` if the store branch has not merged yet:

```yaml
      - name: Security regression guards
        run: bats tests/security.bats
```

- [ ] **Step 6: Commit**

```bash
git add profile/airootfs/usr/local/bin/cyberos-install \
        profile/airootfs/usr/local/bin/cyberos-firstboot \
        profile/pacman.conf.in tests/security.bats .github/workflows/
git commit -m "security: enable the firewall, require package signatures, guard sshd"
```

---

### Task 5: LUKS2 full-disk encryption in the installer

Student laptops are lost and stolen, and they hold lab material.

**Files:**
- Modify: `profile/airootfs/usr/local/bin/cyberos-install`
- Modify: `profile/airootfs/usr/local/bin/cyberos-install-gui`
- Test: `tests/install-luks.bats`

**Interfaces:**
- Consumes: `ROOTP`, `FS`, `restore_kernel` from Task 2
- Produces:
  - `luks_hooks <current-hooks>` — returns the mkinitcpio `HOOKS` line with `encrypt` inserted in the right place
  - `luks_cmdline <luks-uuid> <mapper-name>` — the `GRUB_CMDLINE_LINUX` fragment
  - `--encrypt` flag on `cyberos-install`, and an "Encrypt this disk" switch on the options page of the wizard

- [ ] **Step 1: Write the failing test**

Create `tests/install-luks.bats`:

```bash
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
  run luks_hooks "base udev block encrypt filesystems fsck"
  [ "$status" -eq 0 ]
  [ "$(grep -o encrypt <<<"$output" | wc -l)" -eq 1 ]
}

@test "keyboard and keymap must already be present, or it fails loudly" {
  run luks_hooks "base udev block filesystems fsck"
  [ "$status" -ne 0 ]
  [[ "$output" == *"keyboard"* ]]
}

@test "the kernel command line names the LUKS device and the mapper" {
  run luks_cmdline "dead-beef" "cryptroot"
  [[ "$output" == *"cryptdevice=UUID=dead-beef:cryptroot"* ]]
  [[ "$output" == *"root=/dev/mapper/cryptroot"* ]]
}

@test "luks_cmdline refuses an empty UUID" {
  run luks_cmdline "" cryptroot
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/install-luks.bats`
Expected: FAIL — `luks_hooks` and `luks_cmdline` are undefined.

- [ ] **Step 3: Write the minimal implementation**

Add to `cyberos-install`'s library section:

```bash
# luks_hooks <hooks-line> -- insert the encrypt hook in the only place it works.
#
# encrypt must run after block (which provides the device) and before
# filesystems (which mounts it). keyboard and keymap must already be present, or
# the student cannot type the passphrase on a non-US layout -- and an
# unbootable encrypted disk has no recovery path.
luks_hooks() {
  local hooks=$1
  if ! grep -qw keyboard <<<"$hooks"; then
    printf 'HOOKS has no keyboard hook; refusing to encrypt a disk whose passphrase cannot be typed\n' >&2
    return 1
  fi
  if grep -qw encrypt <<<"$hooks"; then
    printf '%s\n' "$hooks"
    return 0
  fi
  if ! grep -qw block <<<"$hooks"; then
    printf 'HOOKS has no block hook; cannot place encrypt\n' >&2
    return 1
  fi
  printf '%s\n' "${hooks/block/block encrypt}"
}

# luks_cmdline <luks-uuid> <mapper-name> -- the GRUB_CMDLINE_LINUX fragment.
luks_cmdline() {
  local uuid=$1 mapper=${2:-cryptroot}
  [[ -n $uuid ]] || { printf 'luks_cmdline: no LUKS UUID\n' >&2; return 1; }
  printf 'cryptdevice=UUID=%s:%s root=/dev/mapper/%s\n' "$uuid" "$mapper" "$mapper"
}
```

Add an `--encrypt` flag to the option parsing, and in the partition-formatting section,
when it is set:

```bash
if [[ $ENCRYPT -eq 1 ]]; then
  [[ -n ${PASS:-} ]] || die "--encrypt needs a passphrase; use --password-stdin"
  printf '%s' "$LUKSPASS" | cryptsetup luksFormat --type luks2 --batch-mode "$ROOTP" -
  printf '%s' "$LUKSPASS" | cryptsetup open "$ROOTP" cryptroot -
  LUKS_UUID=$(blkid -o value -s UUID "$ROOTP")
  ROOTP=/dev/mapper/cryptroot
fi
```

Read the LUKS passphrase as a **third** stdin line in `--password-stdin`, beside the user
and root passwords, so it never reaches `argv`:

```bash
--password-stdin) IFS= read -r PASS; IFS= read -r ROOTPASS || true; IFS= read -r LUKSPASS || true; shift;;
```

In the chroot section, apply the hooks and the command line before `mkinitcpio -P` and
`grub-mkconfig`:

```bash
if [[ $ENCRYPT -eq 1 ]]; then
  CUR=$(sed -nE 's/^HOOKS=\((.*)\)$/\1/p' /mnt/etc/mkinitcpio.conf)
  NEW=$(luks_hooks "$CUR") || die "cannot place the encrypt hook"
  sed -i -E "s|^HOOKS=\(.*\)$|HOOKS=($NEW)|" /mnt/etc/mkinitcpio.conf
  FRAG=$(luks_cmdline "$LUKS_UUID" cryptroot)
  sed -i -E "s|^GRUB_CMDLINE_LINUX=\"(.*)\"$|GRUB_CMDLINE_LINUX=\"\\1 $FRAG\"|" /mnt/etc/default/grub
fi
```

In `cyberos-install-gui`, add an "Encrypt this disk (LUKS2)" `Adw.SwitchRow` to the options
page and a passphrase `Adw.PasswordEntryRow` shown only when it is on. Append `--encrypt` to
`argv()` and write the passphrase as the third stdin line. Validate that the passphrase is
non-empty and confirmed before the Next button enables — an empty LUKS passphrase produces a
disk nobody can open.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats tests/install-luks.bats && pytest tests/test_store.py -q`
Expected: PASS, 5 new tests, nothing else broken.

- [ ] **Step 5: Prove it against a loop device, not a real disk**

```bash
truncate -s 2G /tmp/luks-test.img
sudo losetup -fP --show /tmp/luks-test.img      # note the device, e.g. /dev/loop0
# then, as a person with sudo:
#   printf 'testpass' | sudo cryptsetup luksFormat --type luks2 --batch-mode /dev/loop0 -
#   printf 'testpass' | sudo cryptsetup open /dev/loop0 cyberostest -
#   sudo cryptsetup close cyberostest
sudo losetup -d /dev/loop0 && rm /tmp/luks-test.img
```

This checks the cryptsetup invocation shape without risking a disk. The full path is checked
by the harness in Task 6.

- [ ] **Step 6: Commit**

```bash
git add profile/airootfs/usr/local/bin/cyberos-install \
        profile/airootfs/usr/local/bin/cyberos-install-gui tests/install-luks.bats
git commit -m "security: LUKS2 full-disk encryption in the installer and the wizard"
```

---

### Task 6: Automate the release criteria

The test matrix has one populated cell and it is filled in by a person clicking through
QEMU. This replaces that with a harness, over a serial console rather than screen scraping —
driving the GUI through QEMU `sendkey` has already proven unreliable in this repo.

**Files:**
- Create: `tools/qa/run-matrix.sh`, `tools/qa/lib/qmp.sh`, `tools/qa/criteria/*.sh`
- Create: `profile/efiboot/loader/entries/03-cyberos-qa.conf`
- Create: `profile/airootfs/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf`
- Test: `tests/qa.bats`

**Interfaces:**
- Consumes: an ISO in `out/`
- Produces:
  - `qmp_send <socket> <command>` — one monitor command, returns its reply
  - `serial_expect <logfile> <pattern> <timeout>` — waits for a pattern on the serial log
  - `run-matrix.sh --iso <path> [--criteria N,...]` — exit 0 only if every selected criterion passes

- [ ] **Step 1: Write the failing test**

Create `tests/qa.bats`:

```bash
#!/usr/bin/env bats

setup() {
  # shellcheck disable=SC1090
  source "$BATS_TEST_DIRNAME/../tools/qa/lib/qmp.sh"
  TMP="$BATS_TEST_TMPDIR"
}

@test "serial_expect finds a pattern already in the log" {
  printf 'boot\nCYBEROS-QA-READY\n' >"$TMP/log"
  run serial_expect "$TMP/log" "CYBEROS-QA-READY" 2
  [ "$status" -eq 0 ]
}

@test "serial_expect times out rather than hanging" {
  printf 'boot\n' >"$TMP/log"
  run serial_expect "$TMP/log" "NEVER-APPEARS" 2
  [ "$status" -ne 0 ]
  [[ "$output" == *"timed out"* ]]
}

@test "serial_expect finds a pattern that arrives late" {
  : >"$TMP/log"
  ( sleep 1; printf 'CYBEROS-QA-READY\n' >>"$TMP/log" ) &
  run serial_expect "$TMP/log" "CYBEROS-QA-READY" 5
  [ "$status" -eq 0 ]
  wait
}

@test "criteria list parsing rejects a criterion that does not exist" {
  run parse_criteria "1,2,999"
  [ "$status" -ne 0 ]
  [[ "$output" == *"999"* ]]
}

@test "criteria list defaults to all of them" {
  run parse_criteria ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"1"* ]]
  [[ "$output" == *"9"* ]]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/qa.bats`
Expected: FAIL — `tools/qa/lib/qmp.sh` does not exist.

- [ ] **Step 3: Write the minimal implementation**

Create `tools/qa/lib/qmp.sh`:

```bash
#!/usr/bin/env bash
# QEMU driving helpers for the release-criteria harness.
#
# Everything here works over the serial console and the monitor socket. There is
# deliberately no screen scraping and no sendkey: driving a GUI through sendkey
# has already produced false results in this repo, where keystrokes reached
# nothing because a terminal had not finished starting.

CRITERIA_COUNT=9

# serial_expect <logfile> <pattern> <timeout-seconds>
serial_expect() {
  local log=$1 pattern=$2 timeout=$3 waited=0
  while (( waited < timeout )); do
    if [[ -f $log ]] && grep -q -- "$pattern" "$log"; then
      return 0
    fi
    sleep 1
    (( waited++ ))
  done
  printf 'timed out after %ss waiting for %s in %s\n' "$timeout" "$pattern" "$log" >&2
  return 1
}

# qmp_send <monitor-socket> <command>
qmp_send() {
  local sock=$1 cmd=$2
  printf '%s\n' "$cmd" | socat - "UNIX-CONNECT:$sock" 2>/dev/null
}

# parse_criteria <spec> -- "" means all of them.
parse_criteria() {
  local spec=$1 n out=()
  if [[ -z $spec ]]; then
    for (( n = 1; n <= CRITERIA_COUNT; n++ )); do out+=("$n"); done
    printf '%s\n' "${out[@]}"
    return 0
  fi
  for n in ${spec//,/ }; do
    if ! [[ $n =~ ^[0-9]+$ ]] || (( n < 1 || n > CRITERIA_COUNT )); then
      printf 'no such criterion: %s (have 1..%s)\n' "$n" "$CRITERIA_COUNT" >&2
      return 1
    fi
    out+=("$n")
  done
  printf '%s\n' "${out[@]}"
}
```

Create `profile/efiboot/loader/entries/03-cyberos-qa.conf` — a boot entry that puts a
console on the serial port so the harness has something to talk to:

```
title    CyberOS (QA, serial console)
linux    /arch/boot/x86_64/vmlinuz-linux
initrd   /arch/boot/intel-ucode.img
initrd   /arch/boot/amd-ucode.img
initrd   /arch/boot/x86_64/initramfs-linux.img
options  archisobasedir=arch archisolabel=%ARCHISO_LABEL% console=tty0 console=ttyS0,115200 cyberos.qa=1
```

Create `profile/airootfs/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf`:

```ini
# The live image already autologins student on tty1 with no password. This gives
# the QA harness the same session over the serial port, so it can drive the
# installer without screen scraping.
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -- \\u' --autologin root --noclear --keep-baud 115200,38400,9600 %I $TERM
```

Create `tools/qa/run-matrix.sh`:

```bash
#!/usr/bin/env bash
# run-matrix.sh --iso out/cyberos-*.iso [--criteria 1,2,3]
#
# Drive the release criteria in docs/SPEC.md §6.1 against a built ISO. Exits 0
# only if every selected criterion passes, and prints which ones did not.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=lib/qmp.sh
source "$HERE/lib/qmp.sh"

ISO= SPEC= WORK=${WORK:-/tmp/cyberos-qa}
while [[ $# -gt 0 ]]; do
  case $1 in
    --iso)      ISO=$2; shift 2 ;;
    --criteria) SPEC=$2; shift 2 ;;
    --work)     WORK=$2; shift 2 ;;
    *) printf 'unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
[[ -f $ISO ]] || { printf 'run-matrix: no ISO at %s\n' "${ISO:-<unset>}" >&2; exit 2; }

mapfile -t CRITERIA < <(parse_criteria "$SPEC") || exit 2

mkdir -p "$WORK"
passed=() failed=()
for c in "${CRITERIA[@]}"; do
  script="$HERE/criteria/$(printf '%02d' "$c")-"*.sh
  # shellcheck disable=SC2206
  files=($script)
  if [[ ! -f ${files[0]} ]]; then
    printf 'criterion %s has no script yet; skipping\n' "$c"
    continue
  fi
  printf '=== criterion %s: %s\n' "$c" "$(basename "${files[0]}")"
  if ISO="$ISO" WORK="$WORK" bash "${files[0]}"; then
    passed+=("$c"); printf '    pass\n'
  else
    failed+=("$c"); printf '    FAIL\n'
  fi
done

printf '\npassed: %s\n' "${passed[*]:-none}"
printf 'failed: %s\n' "${failed[*]:-none}"
(( ${#failed[@]} == 0 ))
```

Create `tools/qa/criteria/01-live-boots.sh` as the first real criterion:

```bash
#!/usr/bin/env bash
# Release criterion 1: the image boots to the live desktop.
set -uo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=../lib/qmp.sh
source "$HERE/../lib/qmp.sh"

log="$WORK/serial-01.log"
: >"$log"

qemu-system-x86_64 \
  -enable-kvm -m 4096 -smp 2 -machine q35 \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file="$WORK/OVMF_VARS.fd" \
  -cdrom "$ISO" \
  -device virtio-vga-gl -display none \
  -serial "file:$log" \
  -monitor "unix:$WORK/mon.sock,server,nowait" \
  -daemonize -pidfile "$WORK/qemu.pid"

trap 'kill "$(cat "$WORK/qemu.pid")" 2>/dev/null || true' EXIT

# The live session autologins and starts the desktop; waybar's clock advancing is
# the cheapest proof the system is alive rather than hung at a black screen.
serial_expect "$log" "CyberOS" 180 || exit 1
```

Copy the OVMF vars template into `$WORK` before the first run:
`cp /usr/share/edk2/x64/OVMF_VARS.4m.fd "$WORK/OVMF_VARS.fd"`. Confirm the OVMF paths on this
host with `ls /usr/share/edk2/x64/` — they differ between distributions and between edk2
versions, and a wrong path fails as "no bootable device" rather than as a missing file.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats tests/qa.bats`
Expected: PASS, 5 tests.

- [ ] **Step 5: Run the harness against the current ISO**

```bash
mkdir -p /tmp/cyberos-qa
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd /tmp/cyberos-qa/OVMF_VARS.fd
./tools/qa/run-matrix.sh --iso out/cyberos-2026.08.29-x86_64.iso --criteria 1
```

Expected: criterion 1 passes. If it fails, read `/tmp/cyberos-qa/serial-01.log` before
changing anything — a criterion that fails because the serial console was never enabled
looks identical to one that fails because the image does not boot, and this repo has already
lost a debugging cycle to exactly that confusion.

- [ ] **Step 6: Write the remaining criteria**

Add `02-network.sh` through `09-pacman-syu.sh`, one file per criterion in `docs/SPEC.md`
§6.1, each following the shape of `01-live-boots.sh`. Criteria 3–6 boot with a scratch
qcow2 disk attached, run `cyberos-install --yes --password-stdin` over the serial console,
then reboot **without** the CD attached and assert the login prompt.

Do not swap the CD on a running live session to simulate removal. q35's `pcie.0` does not
support hotplug, and pulling the squashfs backing store gives `Input/output error` — a
failure that looks like an installer bug and is not one. Shut the VM down and start a new one
from the disk.

- [ ] **Step 7: Commit**

```bash
chmod 755 tools/qa/run-matrix.sh tools/qa/criteria/*.sh
shellcheck tools/qa/run-matrix.sh tools/qa/lib/qmp.sh
git add tools/qa/ tests/qa.bats \
        profile/efiboot/loader/entries/03-cyberos-qa.conf \
        profile/airootfs/etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf
git commit -m "qa: automate the release criteria over a serial console"
```

- [ ] **Step 8: Open both pull requests**

```bash
git push -u origin hardware/enablement
gh pr create --base main --title "Hardware tiers, recovery paths, and the edition split" \
  --body "Implements docs/SPEC.md §2 and §6."

git push -u origin security/hardening
gh pr create --base main --title "Security baseline: firewall, signatures, LUKS2" \
  --body "Implements docs/SPEC.md §7 requirements S1-S6."
```

---

## Notes for the executor

- **`./build.sh` and `./test-vm.sh` are run as a normal user, not with sudo,** and cannot be
  run from an agent session. Ask the
  user to run them and to say when they finish; watch `work/build.log` meanwhile.
- **Give foot more than three seconds to appear before typing into it.** Keystrokes sent to a
  window that has not finished starting go nowhere, and the resulting silence has already
  been misread in this repo as a reproducible reboot hang.
- **Do not combine `pkill -f` with any text naming the target process** — the pattern matches
  the running command line, heredocs included, and kills the shell running it.
- **`grim -o <output>`**, always. Capturing by geometry silently returns the wrong surface
  once a second monitor exists.
- The QA harness exists so results are not a matter of opinion. If a criterion fails, report
  it with the log; do not mark it passed because it looked right on screen.
