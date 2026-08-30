# CyberOS Release Channels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the department control over when student machines change, by pinning `[core]` and `[extra]` to a dated Arch Linux Archive snapshot that only a maintainer advances — while still shipping CVE fixes within 72 hours.

**Architecture:** A channel is a date. `/etc/cyberos/channels.conf` maps `unstable`/`testing`/`stable` to Arch Linux Archive dates; `/etc/cyberos/channel` names the machine's current channel; `cyberos-channel` renders both into a one-line `/etc/pacman.d/cyberos-channel` that `pacman.conf` includes for `[core]` and `[extra]`. `channels.conf` is itself shipped by a `cyberos-channels` pacman package, so promoting a channel department-wide is publishing a package — no extra hosting, no config management. Security fixes bypass the pin through `[cyberos-security]`, which sits above `[core]`/`[extra]` in pacman's repository precedence order.

**Tech Stack:** Bash, pacman 7.1, `repo-add` (pacman), `bats` 1.14 for tests, `arch-audit` 0.2, systemd timers.

**Spec:** `docs/SPEC.md` §4 (release engineering), §7.4 (vulnerability handling)

## Global Constraints

- Branch: `channels/release-engineering`, off `main`. Rebase onto `main`; never merge `main` in.
- Commit author is `edbron <edbron411@gmail.com>`. The repo has a local `git config user.email`; do not override it.
- Every executable added under `profile/airootfs/` MUST be listed in `profile/profiledef.sh` `file_permissions`. `mkarchiso` copies `airootfs/` with `cp -af --no-preserve=ownership,mode`, so git's 755 on the source file is **not** enough — the file arrives non-executable.
- Arch Linux Archive URL form, exactly: `https://archive.archlinux.org/repos/YYYY/MM/DD/$repo/os/$arch`. `$repo` and `$arch` are pacman variables and MUST reach the file unexpanded — use single-quoted `printf` format strings.
- `[cyberos-security]` entries MUST cite a CVE or Arch AVG identifier in the commit message. It is not a route for feature updates.
- A CVSS ≥ 7.0 fix MUST publish within 72 hours of the Arch Security Advisory.
- Build-host test dependency only: `bats`, `shellcheck`. Neither ships in the ISO.
- Do not mirror `core`/`extra`. The Arch Linux Archive already is that mirror.

## File Structure

| File | Responsibility |
|---|---|
| `profile/airootfs/usr/local/bin/cyberos-channel` | The whole client. Pure helpers + a `main` guarded so tests can source it. |
| `profile/airootfs/etc/cyberos/channels.conf` | channel → date map. Owned by the `cyberos-channels` package. |
| `profile/airootfs/etc/cyberos/channel` | which channel this machine is on |
| `profile/airootfs/etc/pacman.d/cyberos-channel` | generated; one `Server =` or `Include =` line |
| `profile/airootfs/etc/pacman.conf` | repository precedence order |
| `profile/airootfs/etc/systemd/system/cyberos-audit.{service,timer}` | weekly `arch-audit` report |
| `packages/cyberos-channels/PKGBUILD` | ships `channels.conf`; promoting a channel bumps this |
| `tools/promote-channel.sh` | maintainer side: advance a channel's date |
| `tools/security-backport.sh` | maintainer side: copy one fixed package into `[cyberos-security]` |
| `tests/channel.bats` | tests for the pure helpers |

`cyberos-channel` stays one file. Its logic is ~150 lines and splitting it across a library would mean shipping two files and listing two `file_permissions` entries for no gain.

---

### Task 1: Channel resolution helpers

The two functions everything else is built on: given a channel name, find its pinned date; given a date, render the pacman server line.

**Files:**
- Create: `profile/airootfs/usr/local/bin/cyberos-channel`
- Create: `profile/airootfs/etc/cyberos/channels.conf`
- Test: `tests/channel.bats`

**Interfaces:**
- Consumes: nothing
- Produces:
  - `pin_for <channel> [conf-path]` → prints the date `YYYY/MM/DD`, or an empty line for a rolling channel. Exit 1 if the channel is not in the file.
  - `render_pin <pin>` → prints one pacman config line. Empty pin renders `Include = /etc/pacman.d/mirrorlist`.
  - `validate_date <string>` → exit 0 if it is a real `YYYY/MM/DD` date.
  - `CHANNELS_CONF`, `CHANNEL_STATE`, `PIN_FILE` — overridable path variables, so tests never touch `/etc`.

- [ ] **Step 1: Write the failing test**

Create `tests/channel.bats`:

```bash
#!/usr/bin/env bats

setup() {
  CHANNEL_BIN="$BATS_TEST_DIRNAME/../profile/airootfs/usr/local/bin/cyberos-channel"
  TMP="$BATS_TEST_TMPDIR"
  cat >"$TMP/channels.conf" <<'CONF'
# channel = Arch Linux Archive date, empty means rolling
unstable =
testing  = 2026/08/20
stable   = 2026/08/01
CONF
  # shellcheck disable=SC1090
  source "$CHANNEL_BIN"
  CHANNELS_CONF="$TMP/channels.conf"
}

@test "pin_for reads a pinned channel" {
  run pin_for stable
  [ "$status" -eq 0 ]
  [ "$output" = "2026/08/01" ]
}

@test "pin_for returns empty for a rolling channel" {
  run pin_for unstable
  [ "$status" -eq 0 ]
  [ "$output" = "" ]
}

@test "pin_for rejects an unknown channel" {
  run pin_for nonesuch
  [ "$status" -ne 0 ]
}

@test "render_pin builds an archive URL with pacman variables intact" {
  run render_pin 2026/08/01
  [ "$output" = 'Server = https://archive.archlinux.org/repos/2026/08/01/$repo/os/$arch' ]
}

@test "render_pin falls back to the rolling mirrorlist" {
  run render_pin ""
  [ "$output" = "Include = /etc/pacman.d/mirrorlist" ]
}

@test "validate_date accepts a real date and rejects nonsense" {
  run validate_date 2026/08/01 ; [ "$status" -eq 0 ]
  run validate_date 2026-08-01 ; [ "$status" -ne 0 ]
  run validate_date 2026/13/01 ; [ "$status" -ne 0 ]
  run validate_date banana     ; [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/channel.bats`
Expected: FAIL — `cyberos-channel` does not exist, so `source` errors on every test.

- [ ] **Step 3: Write the minimal implementation**

Create `profile/airootfs/etc/cyberos/channels.conf`:

```
# CyberOS release channels.
#
# Each channel pins [core] and [extra] to a dated snapshot in the Arch Linux
# Archive. An empty value means "roll with upstream" and is for maintainers only.
#
# This file is shipped by the cyberos-channels package. Promoting a channel is
# publishing a new version of that package -- do not edit it by hand on a
# student machine, it will be overwritten on the next upgrade.

unstable =
testing  = 2026/08/20
stable   = 2026/08/01
```

Create `profile/airootfs/usr/local/bin/cyberos-channel`:

```bash
#!/usr/bin/env bash
# cyberos-channel -- read, set and freeze this machine's update channel.
#
# A channel is a date. Student machines point [core] and [extra] at a dated
# snapshot in the Arch Linux Archive, so pacman -Syu produces the same system
# on every machine until a maintainer moves the date.

# Only when executed: `set -u` leaks into bats and breaks its internals when
# this file is sourced by the test suite.
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  set -euo pipefail
fi

: "${CHANNELS_CONF:=/etc/cyberos/channels.conf}"
: "${CHANNEL_STATE:=/etc/cyberos/channel}"
: "${PIN_FILE:=/etc/pacman.d/cyberos-channel}"

ARCHIVE=https://archive.archlinux.org/repos

die() { printf 'cyberos-channel: %s\n' "$*" >&2; exit 1; }

# pin_for <channel> -- print the pinned date, empty for a rolling channel.
pin_for() {
  local channel=$1 key value
  [[ -r ${CHANNELS_CONF} ]] || die "cannot read ${CHANNELS_CONF}"
  while IFS='=' read -r key value; do
    key=${key//[[:space:]]/}
    [[ -n $key && $key != '#'* ]] || continue
    if [[ $key == "$channel" ]]; then
      printf '%s\n' "${value//[[:space:]]/}"
      return 0
    fi
  done < "${CHANNELS_CONF}"
  return 1
}

# render_pin <date> -- print the pacman config line for that date.
# $repo and $arch are pacman variables and must not be expanded by bash.
render_pin() {
  local pin=$1
  if [[ -z $pin ]]; then
    printf 'Include = /etc/pacman.d/mirrorlist\n'
  else
    printf 'Server = %s/%s/$repo/os/$arch\n' "$ARCHIVE" "$pin"
  fi
}

# validate_date <string> -- exit 0 if it is a real YYYY/MM/DD date.
validate_date() {
  [[ $1 =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] || return 1
  date -d "${1//\//-}" +%s >/dev/null 2>&1
}

# Only run main when executed, so tests can source this file.
if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  die "not implemented yet"
fi
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats tests/channel.bats`
Expected: PASS, 6 tests.

- [ ] **Step 5: Lint and commit**

```bash
shellcheck profile/airootfs/usr/local/bin/cyberos-channel
git add profile/airootfs/usr/local/bin/cyberos-channel \
        profile/airootfs/etc/cyberos/channels.conf tests/channel.bats
git commit -m "channels: resolve a channel name to an Arch Linux Archive pin"
```

---

### Task 2: Downgrade and distance guards

Moving a channel backwards downgrades every package on the machine, which pacman will not
do without `-Syuu`. Moving forward across many snapshots skips everything the skipped
snapshots tested. Both need to be detected before the pin is written, not after.

**Files:**
- Modify: `profile/airootfs/usr/local/bin/cyberos-channel`
- Test: `tests/channel.bats`

**Interfaces:**
- Consumes: `pin_for`, `validate_date` from Task 1
- Produces:
  - `pin_epoch <pin>` → seconds since epoch; an empty pin means "now"
  - `is_downgrade <from-pin> <to-pin>` → exit 0 when `to` is earlier than `from`
  - `snapshot_distance <from-pin> <to-pin>` → whole 30-day periods between them, always positive

- [ ] **Step 1: Write the failing test**

Append to `tests/channel.bats`:

```bash
@test "is_downgrade detects moving backwards" {
  run is_downgrade 2026/08/20 2026/08/01
  [ "$status" -eq 0 ]
}

@test "is_downgrade allows moving forwards" {
  run is_downgrade 2026/08/01 2026/08/20
  [ "$status" -ne 0 ]
}

@test "leaving a rolling channel for any pin is a downgrade" {
  run is_downgrade "" 2026/08/01
  [ "$status" -eq 0 ]
}

@test "joining a rolling channel from a pin is not a downgrade" {
  run is_downgrade 2026/08/01 ""
  [ "$status" -ne 0 ]
}

@test "snapshot_distance counts 30-day periods and is never negative" {
  run snapshot_distance 2026/01/01 2026/05/01 ; [ "$output" -eq 4 ]
  run snapshot_distance 2026/05/01 2026/01/01 ; [ "$output" -eq 4 ]
  run snapshot_distance 2026/08/01 2026/08/20 ; [ "$output" -eq 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/channel.bats`
Expected: FAIL on the five new tests with "command not found: is_downgrade".

- [ ] **Step 3: Write the minimal implementation**

Insert into `cyberos-channel` after `validate_date`:

```bash
# pin_epoch <date> -- seconds since epoch. An empty pin means "now".
pin_epoch() {
  if [[ -z $1 ]]; then date +%s; else date -d "${1//\//-}" +%s; fi
}

# is_downgrade <from> <to> -- exit 0 when <to> is earlier than <from>.
is_downgrade() {
  local from to
  from=$(pin_epoch "$1"); to=$(pin_epoch "$2")
  (( to < from ))
}

# snapshot_distance <from> <to> -- whole 30-day periods between them.
snapshot_distance() {
  local from to days
  from=$(pin_epoch "$1"); to=$(pin_epoch "$2")
  days=$(( (to - from) / 86400 ))
  (( days < 0 )) && days=$(( -days ))
  printf '%s\n' $(( days / 30 ))
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats tests/channel.bats`
Expected: PASS, 11 tests.

- [ ] **Step 5: Commit**

```bash
shellcheck profile/airootfs/usr/local/bin/cyberos-channel
git add profile/airootfs/usr/local/bin/cyberos-channel tests/channel.bats
git commit -m "channels: detect downgrades and long snapshot jumps before pinning"
```

---

### Task 3: The `cyberos-channel` command

Wire the helpers into the three things a person does: see where they are, move channel,
freeze to a date for an exam week.

**Files:**
- Modify: `profile/airootfs/usr/local/bin/cyberos-channel`
- Create: `profile/airootfs/etc/cyberos/channel`
- Modify: `profile/airootfs/etc/pacman.conf`
- Modify: `profile/profiledef.sh`
- Test: `tests/channel.bats`

**Interfaces:**
- Consumes: everything from Tasks 1 and 2
- Produces:
  - `write_pin <pin>` → writes `$PIN_FILE` atomically, prints nothing
  - `cmd_status`, `cmd_set <channel>`, `cmd_freeze <date>`, `main "$@"`

- [ ] **Step 1: Write the failing test**

Append to `tests/channel.bats`:

```bash
@test "write_pin writes exactly one line, atomically" {
  PIN_FILE="$TMP/pin"
  write_pin 2026/08/01
  [ "$(wc -l <"$PIN_FILE")" -eq 1 ]
  [ "$(cat "$PIN_FILE")" = 'Server = https://archive.archlinux.org/repos/2026/08/01/$repo/os/$arch' ]
  [ ! -e "$PIN_FILE.tmp" ]
}

@test "status reports the channel and its pin" {
  PIN_FILE="$TMP/pin"; CHANNEL_STATE="$TMP/channel"
  echo stable >"$CHANNEL_STATE"
  run cmd_status
  [ "$status" -eq 0 ]
  [[ "$output" == *"stable"* ]]
  [[ "$output" == *"2026/08/01"* ]]
}

@test "set rejects a channel that is not in channels.conf" {
  PIN_FILE="$TMP/pin"; CHANNEL_STATE="$TMP/channel"
  echo stable >"$CHANNEL_STATE"
  run cmd_set nonesuch
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown channel"* ]]
}

@test "set warns about a downgrade and names -Syuu" {
  PIN_FILE="$TMP/pin"; CHANNEL_STATE="$TMP/channel"; AUTO_YES=1
  echo testing >"$CHANNEL_STATE"
  run cmd_set stable
  [ "$status" -eq 0 ]
  [[ "$output" == *"Syuu"* ]]
  [ "$(cat "$CHANNEL_STATE")" = "stable" ]
}

@test "freeze rejects a malformed date" {
  PIN_FILE="$TMP/pin"; CHANNEL_STATE="$TMP/channel"
  echo stable >"$CHANNEL_STATE"
  run cmd_freeze 2026-08-01
  [ "$status" -ne 0 ]
}

@test "freeze pins the date and records the frozen channel" {
  PIN_FILE="$TMP/pin"; CHANNEL_STATE="$TMP/channel"; AUTO_YES=1
  echo stable >"$CHANNEL_STATE"
  run cmd_freeze 2026/08/01
  [ "$status" -eq 0 ]
  [ "$(cat "$CHANNEL_STATE")" = "frozen 2026/08/01" ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/channel.bats`
Expected: FAIL on the six new tests — `write_pin`, `cmd_status`, `cmd_set`, `cmd_freeze` are undefined.

- [ ] **Step 3: Write the minimal implementation**

Replace the `if [[ ${BASH_SOURCE[0]} == "${0}" ]]` block at the end of `cyberos-channel` with:

```bash
# write_pin <date> -- atomically replace the pacman pin file.
#
# One line, no comments: pacman Includes this file, and the whole point is that
# a person can read the machine's pin at a glance with cat.
write_pin() {
  local tmp="${PIN_FILE}.tmp"
  render_pin "$1" >"$tmp"
  mv "$tmp" "$PIN_FILE"
}

current_channel() {
  [[ -r $CHANNEL_STATE ]] && cat "$CHANNEL_STATE" || echo stable
}

# Resolve a channel-state line ("stable" or "frozen 2026/08/01") to a pin.
current_pin() {
  local state; state=$(current_channel)
  if [[ $state == frozen\ * ]]; then
    printf '%s\n' "${state#frozen }"
  else
    pin_for "$state"
  fi
}

cmd_status() {
  local state pin; state=$(current_channel); pin=$(current_pin)
  printf 'channel : %s\n' "$state"
  printf 'pinned  : %s\n' "${pin:-rolling (upstream Arch)}"
  printf 'source  : %s\n' "$(render_pin "$pin")"
}

confirm() {
  [[ ${AUTO_YES:-0} -eq 1 ]] && return 0
  local reply; read -r -p "$1 [y/N] " reply
  [[ $reply == [yY] ]]
}

cmd_set() {
  local target=$1 from to
  from=$(current_pin)
  to=$(pin_for "$target") || die "unknown channel '$target' -- see $CHANNELS_CONF"
  if is_downgrade "$from" "$to"; then
    printf 'Moving to %s goes BACKWARDS in time (%s -> %s).\n' "$target" "${from:-today}" "${to:-today}"
    printf 'Every package will be downgraded. Complete it with: pacman -Syuu\n'
    confirm "Continue?" || die "cancelled"
  elif [[ $(snapshot_distance "$from" "$to") -gt 3 ]]; then
    printf 'Warning: %s is more than three snapshots ahead of %s.\n' "${to:-today}" "${from:-today}"
    printf 'The further the jump, the less of it was tested together.\n'
    confirm "Continue?" || die "cancelled"
  fi
  write_pin "$to"
  printf '%s\n' "$target" >"$CHANNEL_STATE"
  printf 'Now on %s (%s). Run: pacman -Syu\n' "$target" "${to:-rolling}"
}

cmd_freeze() {
  local date=$1 from
  validate_date "$date" || die "not a YYYY/MM/DD date: $date"
  from=$(current_pin)
  if is_downgrade "$from" "$date"; then
    printf 'Freezing at %s goes backwards from %s. Complete it with: pacman -Syuu\n' "$date" "${from:-today}"
    confirm "Continue?" || die "cancelled"
  fi
  write_pin "$date"
  printf 'frozen %s\n' "$date" >"$CHANNEL_STATE"
  printf 'Frozen at %s. Release it with: cyberos-channel set stable\n' "$date"
}

usage() {
  cat <<'USAGE'
cyberos-channel -- control when this machine's packages change.

  cyberos-channel                   show the channel and its pinned date
  cyberos-channel set <channel>     switch channel (stable, testing, unstable)
  cyberos-channel freeze <date>     pin to an explicit YYYY/MM/DD snapshot
  cyberos-channel list              show every channel and its date

  --yes    do not ask for confirmation

A channel is a date. Until a maintainer moves it, pacman -Syu produces the same
system on every machine on that channel.
USAGE
}

main() {
  local args=() a
  for a in "$@"; do
    case $a in
      --yes|-y) AUTO_YES=1 ;;
      -h|--help) usage; return 0 ;;
      *) args+=("$a") ;;
    esac
  done
  set -- "${args[@]+"${args[@]}"}"
  case ${1:-status} in
    status) cmd_status ;;
    list)   grep -v '^[[:space:]]*#' "$CHANNELS_CONF" | grep -v '^[[:space:]]*$' ;;
    set)    [[ -n ${2:-} ]] || die "set needs a channel name"; cmd_set "$2" ;;
    freeze) [[ -n ${2:-} ]] || die "freeze needs a YYYY/MM/DD date"; cmd_freeze "$2" ;;
    *)      die "unknown command '$1' -- try --help" ;;
  esac
}

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
  main "$@"
fi
```

Create `profile/airootfs/etc/cyberos/channel` containing exactly:

```
stable
```

In `profile/airootfs/etc/pacman.conf`, replace the `[core]` and `[extra]` blocks with the
pinned form and put the department repos above them, so pacman's first-match-wins
precedence lets `[cyberos-security]` override the pin:

```
# Department repositories come first: pacman resolves a package from the FIRST
# repository that contains it, so [cyberos-security] can override the pin below
# for a single CVE-fixed package without moving the whole channel.

[cyberos-security]
SigLevel = Required DatabaseRequired TrustedOnly
Include  = /etc/pacman.d/cyberos-repos

[cyberos-apps]
SigLevel = Required DatabaseRequired TrustedOnly
Include  = /etc/pacman.d/cyberos-repos

[cyberos]
SigLevel = Required DatabaseRequired TrustedOnly
Include  = /etc/pacman.d/cyberos-repos

# Pinned to this machine's channel by cyberos-channel(1).
[core]
Include = /etc/pacman.d/cyberos-channel

[extra]
Include = /etc/pacman.d/cyberos-channel
```

Add to `profile/profiledef.sh` `file_permissions`:

```bash
  ["/usr/local/bin/cyberos-channel"]="0:0:755"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats tests/channel.bats`
Expected: PASS, 17 tests.

- [ ] **Step 5: Check the command end to end on the host**

```bash
CHANNELS_CONF=profile/airootfs/etc/cyberos/channels.conf \
CHANNEL_STATE=/tmp/ch CHANNEL=stable PIN_FILE=/tmp/pin \
  bash profile/airootfs/usr/local/bin/cyberos-channel status
cat /tmp/pin
```

Expected: `channel : stable`, `pinned : 2026/08/01`, and `/tmp/pin` holding the archive URL
with a literal `$repo` and `$arch`.

- [ ] **Step 6: Commit**

```bash
shellcheck profile/airootfs/usr/local/bin/cyberos-channel
git add profile/airootfs/usr/local/bin/cyberos-channel \
        profile/airootfs/etc/cyberos/channel \
        profile/airootfs/etc/pacman.conf profile/profiledef.sh tests/channel.bats
git commit -m "channels: cyberos-channel command and pinned pacman repositories"
```

---

### Task 4: Ship the channel map as a package

Promoting a channel department-wide must not mean touching 40 machines. `channels.conf`
belongs to a package; publishing a new version of it moves every machine on the next
upgrade.

**Files:**
- Create: `packages/cyberos-channels/PKGBUILD`
- Create: `tools/promote-channel.sh`
- Test: `tests/promote.bats`

**Interfaces:**
- Consumes: `profile/airootfs/etc/cyberos/channels.conf` as the source of truth
- Produces: `tools/promote-channel.sh <channel> <YYYY/MM/DD>` — rewrites that channel's line in `channels.conf` and bumps `pkgrel` in the PKGBUILD.

- [ ] **Step 1: Write the failing test**

Create `tests/promote.bats`:

```bash
#!/usr/bin/env bats

setup() {
  PROMOTE="$BATS_TEST_DIRNAME/../tools/promote-channel.sh"
  TMP="$BATS_TEST_TMPDIR"
  cat >"$TMP/channels.conf" <<'CONF'
# comment
unstable =
testing  = 2026/08/20
stable   = 2026/08/01
CONF
  cat >"$TMP/PKGBUILD" <<'PKG'
pkgname=cyberos-channels
pkgver=2026.08
pkgrel=1
PKG
  export CHANNELS_CONF="$TMP/channels.conf" PKGBUILD_PATH="$TMP/PKGBUILD"
}

@test "promote rewrites only the named channel" {
  run bash "$PROMOTE" stable 2026/09/01
  [ "$status" -eq 0 ]
  grep -q 'stable   = 2026/09/01' "$CHANNELS_CONF"
  grep -q 'testing  = 2026/08/20' "$CHANNELS_CONF"
}

@test "promote bumps pkgrel" {
  run bash "$PROMOTE" stable 2026/09/01
  grep -q '^pkgrel=2$' "$PKGBUILD_PATH"
}

@test "promote refuses to move a channel backwards" {
  run bash "$PROMOTE" stable 2026/07/01
  [ "$status" -ne 0 ]
  [[ "$output" == *"backwards"* ]]
  grep -q 'stable   = 2026/08/01' "$CHANNELS_CONF"
}

@test "promote refuses a malformed date" {
  run bash "$PROMOTE" stable 2026-09-01
  [ "$status" -ne 0 ]
}

@test "promote refuses an unknown channel" {
  run bash "$PROMOTE" nonesuch 2026/09/01
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/promote.bats`
Expected: FAIL — `tools/promote-channel.sh` does not exist.

- [ ] **Step 3: Write the minimal implementation**

Create `packages/cyberos-channels/PKGBUILD`:

```bash
# Maintainer: edbron <edbron411@gmail.com>
#
# The CyberOS channel map. Promoting a channel department-wide is publishing a
# new version of this package: every machine picks it up on the next upgrade.
pkgname=cyberos-channels
pkgver=2026.08
pkgrel=1
pkgdesc="CyberOS release channel definitions"
arch=('any')
url="https://github.com/edbron/cyberos"
license=('MIT')
backup=('etc/cyberos/channels.conf')
source=('channels.conf')
sha256sums=('SKIP')

package() {
  install -Dm644 "$srcdir/channels.conf" "$pkgdir/etc/cyberos/channels.conf"
}
```

Create `tools/promote-channel.sh`:

```bash
#!/usr/bin/env bash
# promote-channel.sh <channel> <YYYY/MM/DD>
#
# Advance a channel to a new Arch Linux Archive snapshot and bump the
# cyberos-channels package so student machines pick it up.
set -euo pipefail

: "${CHANNELS_CONF:=profile/airootfs/etc/cyberos/channels.conf}"
: "${PKGBUILD_PATH:=packages/cyberos-channels/PKGBUILD}"

die() { printf 'promote-channel: %s\n' "$*" >&2; exit 1; }

channel=${1:-} date=${2:-}
[[ -n $channel && -n $date ]] || die "usage: promote-channel.sh <channel> <YYYY/MM/DD>"
[[ $date =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]] || die "not a YYYY/MM/DD date: $date"
date -d "${date//\//-}" +%s >/dev/null 2>&1 || die "not a real date: $date"

grep -qE "^[[:space:]]*${channel}[[:space:]]*=" "$CHANNELS_CONF" \
  || die "unknown channel '$channel' in $CHANNELS_CONF"

old=$(sed -nE "s@^[[:space:]]*${channel}[[:space:]]*=[[:space:]]*(.*)@\1@p" "$CHANNELS_CONF")
if [[ -n $old ]]; then
  if [[ $(date -d "${date//\//-}" +%s) -lt $(date -d "${old//\//-}" +%s) ]]; then
    die "refusing to move $channel backwards: $old -> $date"
  fi
fi

# Preserve the column alignment of the file.
sed -i -E "s@^([[:space:]]*${channel}[[:space:]]*=[[:space:]]*).*@\1${date}@" "$CHANNELS_CONF"

rel=$(sed -nE 's/^pkgrel=([0-9]+)$/\1/p' "$PKGBUILD_PATH")
[[ -n $rel ]] || die "no pkgrel in $PKGBUILD_PATH"
sed -i -E "s/^pkgrel=[0-9]+$/pkgrel=$(( rel + 1 ))/" "$PKGBUILD_PATH"

printf 'promoted %s: %s -> %s (pkgrel %s -> %s)\n' \
  "$channel" "${old:-rolling}" "$date" "$rel" "$(( rel + 1 ))"
```

Then `chmod 755 tools/promote-channel.sh`.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats tests/promote.bats`
Expected: PASS, 5 tests.

- [ ] **Step 5: Commit**

```bash
chmod 755 tools/promote-channel.sh
shellcheck tools/promote-channel.sh
git add packages/cyberos-channels/PKGBUILD tools/promote-channel.sh tests/promote.bats
git commit -m "channels: ship the channel map as a package and promote it with one command"
```

---

### Task 5: Security backports past the pin

The pin freezes security fixes too, which would be worse than rolling. This is the escape
hatch: copy one fixed package into `[cyberos-security]`, which outranks the pinned
`[core]`/`[extra]`.

**Files:**
- Create: `tools/security-backport.sh`
- Create: `profile/airootfs/etc/systemd/system/cyberos-audit.service`
- Create: `profile/airootfs/etc/systemd/system/cyberos-audit.timer`
- Modify: `profile/packages.x86_64`
- Test: `tests/backport.bats`

**Interfaces:**
- Consumes: `pin_for` semantics from Task 1 (a date), the repo layout from `tools/release.sh`
- Produces: `tools/security-backport.sh --pkg <name> --cve <ID> [--repo-dir DIR] [--key KEYID]` — fetches the current package from a live Arch mirror, adds it to the `[cyberos-security]` database, signs it.

- [ ] **Step 1: Write the failing test**

Create `tests/backport.bats`:

```bash
#!/usr/bin/env bats

setup() {
  BACKPORT="$BATS_TEST_DIRNAME/../tools/security-backport.sh"
  TMP="$BATS_TEST_TMPDIR"
}

@test "backport requires a CVE or AVG identifier" {
  run bash "$BACKPORT" --pkg curl --repo-dir "$TMP" --unsigned
  [ "$status" -ne 0 ]
  [[ "$output" == *"--cve"* ]]
}

@test "backport rejects an identifier that is not a CVE or AVG" {
  run bash "$BACKPORT" --pkg curl --cve "urgent-fix" --repo-dir "$TMP" --unsigned
  [ "$status" -ne 0 ]
  [[ "$output" == *"CVE-"* ]]
}

@test "backport accepts a CVE identifier" {
  run bash "$BACKPORT" --pkg curl --cve CVE-2026-1234 --repo-dir "$TMP" --unsigned --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"CVE-2026-1234"* ]]
}

@test "backport accepts an Arch AVG identifier" {
  run bash "$BACKPORT" --pkg curl --cve AVG-2900 --repo-dir "$TMP" --unsigned --dry-run
  [ "$status" -eq 0 ]
}

@test "backport refuses to run unsigned unless told to" {
  run bash "$BACKPORT" --pkg curl --cve CVE-2026-1234 --repo-dir "$TMP" --dry-run
  [ "$status" -ne 0 ]
  [[ "$output" == *"--key"* ]]
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bats tests/backport.bats`
Expected: FAIL — `tools/security-backport.sh` does not exist.

- [ ] **Step 3: Write the minimal implementation**

Create `tools/security-backport.sh`:

```bash
#!/usr/bin/env bash
# security-backport.sh --pkg <name> --cve <CVE-YYYY-NNNN|AVG-NNNN>
#
# Copy ONE package from current Arch into [cyberos-security], which outranks the
# pinned [core]/[extra] in pacman.conf. This is how a CVE fix reaches student
# machines without moving the whole channel forward.
#
# This tool is for security fixes only. Every use must cite a CVE or an Arch
# Vulnerability Group identifier, and the entry must be removed once the channel
# pin advances past the fixed version.
set -euo pipefail

die() { printf 'security-backport: %s\n' "$*" >&2; exit 1; }

PKG= CVE= REPO_DIR=dist/cyberos-repo/x86_64 KEY= UNSIGNED=0 DRYRUN=0
while [[ $# -gt 0 ]]; do
  case $1 in
    --pkg)      PKG=$2; shift 2 ;;
    --cve)      CVE=$2; shift 2 ;;
    --repo-dir) REPO_DIR=$2; shift 2 ;;
    --key)      KEY=$2; shift 2 ;;
    --unsigned) UNSIGNED=1; shift ;;
    --dry-run)  DRYRUN=1; shift ;;
    *) die "unknown argument: $1" ;;
  esac
done

[[ -n $PKG ]] || die "--pkg is required"
[[ -n $CVE ]] || die "--cve is required: every backport must cite a CVE or AVG identifier"
[[ $CVE =~ ^(CVE-[0-9]{4}-[0-9]{4,}|AVG-[0-9]+)$ ]] \
  || die "not a CVE- or AVG- identifier: $CVE"
[[ -n $KEY || $UNSIGNED -eq 1 ]] \
  || die "signing key required: pass --key <KEYID>, or --unsigned for a local test repo"

printf 'backporting %s for %s into %s\n' "$PKG" "$CVE" "$REPO_DIR"
[[ $DRYRUN -eq 1 ]] && exit 0

mkdir -p "$REPO_DIR"
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

# Fetch the current version from a live mirror, not from the pinned snapshot.
pacman --noconfirm --config /etc/pacman.conf --cachedir "$tmp" -Sw "$PKG" \
  || die "could not download $PKG from a live mirror"

shopt -s nullglob
files=("$tmp"/*.pkg.tar.zst)
(( ${#files[@]} )) || die "no package files downloaded"

for f in "${files[@]}"; do
  cp -- "$f" "$REPO_DIR/"
  if [[ $UNSIGNED -eq 0 ]]; then
    gpg --detach-sign --local-user "$KEY" --yes "$REPO_DIR/$(basename "$f")"
  fi
done

if [[ $UNSIGNED -eq 0 ]]; then
  repo-add --sign --key "$KEY" "$REPO_DIR/cyberos-security.db.tar.gz" "$REPO_DIR"/*.pkg.tar.zst
else
  repo-add "$REPO_DIR/cyberos-security.db.tar.gz" "$REPO_DIR"/*.pkg.tar.zst
fi

cat <<NOTE

Backported ${PKG} for ${CVE}.

Remaining steps, both required:
  1. Commit with ${CVE} in the message.
  2. Record it so it is REMOVED once the channel pin passes this version --
     [cyberos-security] must not quietly become a fork of Arch.
NOTE
```

Create `profile/airootfs/etc/systemd/system/cyberos-audit.service`:

```ini
[Unit]
Description=Report known vulnerabilities in installed packages
Documentation=https://security.archlinux.org
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/arch-audit --upgradable
```

Create `profile/airootfs/etc/systemd/system/cyberos-audit.timer`:

```ini
[Unit]
Description=Weekly vulnerability report

[Timer]
OnCalendar=weekly
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
```

Add `arch-audit` to `profile/packages.x86_64` in the security-lab section.

- [ ] **Step 4: Run the test to verify it passes**

Run: `bats tests/backport.bats`
Expected: PASS, 5 tests.

- [ ] **Step 5: Enable the timer in the image**

```bash
mkdir -p profile/airootfs/etc/systemd/system/timers.target.wants
ln -sf ../cyberos-audit.timer \
  profile/airootfs/etc/systemd/system/timers.target.wants/cyberos-audit.timer
```

- [ ] **Step 6: Commit**

```bash
chmod 755 tools/security-backport.sh
shellcheck tools/security-backport.sh
git add tools/security-backport.sh tests/backport.bats profile/packages.x86_64 \
        profile/airootfs/etc/systemd/system/cyberos-audit.service \
        profile/airootfs/etc/systemd/system/cyberos-audit.timer \
        profile/airootfs/etc/systemd/system/timers.target.wants/cyberos-audit.timer
git commit -m "channels: backport CVE fixes past the pin, and audit weekly for them"
```

---

### Task 6: Prove it on a built ISO

Everything above is tested on the host. The failure mode this catches is the one this repo
has hit repeatedly: a file that is correct in git and arrives non-executable in the image,
because `mkarchiso` copies `airootfs/` with `--no-preserve=mode`.

**Files:**
- Modify: `docs/branches/channels-release-engineering.md` (record the result)
- Verify: `profile/profiledef.sh`

**Interfaces:**
- Consumes: the built ISO from `./build.sh`
- Produces: a recorded pass or fail against release criteria 9 in `docs/SPEC.md` §6.1

- [ ] **Step 1: Confirm the permissions entry exists before building**

```bash
grep -n 'cyberos-channel' profile/profiledef.sh
```

Expected: one line, `["/usr/local/bin/cyberos-channel"]="0:0:755"`. If it is missing, the
built ISO will ship the file non-executable and the rest of this task fails. This check is
cheaper than a 30-minute rebuild.

- [ ] **Step 2: Build**

`./build.sh` must be run **by a person** — `sudo` cannot take a password from an agent
session. Ask the user to run it and to say when the build finishes; watch `work/build.log`
meanwhile. The only expected warning is `customize_airootfs.sh is deprecated`.

- [ ] **Step 3: Boot the ISO and check the command shipped correctly**

`./test-vm.sh`, then in the live session (open a terminal with `Super+Enter` and give foot
more than three seconds to appear before typing — keystrokes sent too early go nowhere):

```bash
ls -l /usr/local/bin/cyberos-channel
cyberos-channel
cyberos-channel list
cat /etc/pacman.d/cyberos-channel
```

Expected: mode `-rwxr-xr-x`; `channel : stable`; `pinned : 2026/08/01`; the pin file holding
a literal `$repo` and `$arch`.

- [ ] **Step 4: Confirm the pin actually resolves**

```bash
sudo pacman -Sy
pacman -Si bash | grep -E 'Repository|Version'
```

Expected: `-Sy` succeeds against `archive.archlinux.org`, and the version matches what Arch
shipped on the pinned date rather than today's. This is release criterion 9.

- [ ] **Step 5: Record the result and commit**

Add a "Verified on build #NN" line to `docs/branches/channels-release-engineering.md` with
what passed and what did not. State failures plainly; a channel that silently falls back to
the rolling mirrorlist looks identical to one that works until a student's machine changes
underneath them.

```bash
git add docs/branches/channels-release-engineering.md
git commit -m "channels: record ISO verification for build #NN"
```

- [ ] **Step 6: Open the pull request**

```bash
git push -u origin channels/release-engineering
gh pr create --base main --title "Controlled, delayed rolling updates" \
  --body "Implements docs/SPEC.md §4. A channel is a date; [cyberos-security] carries CVE fixes past the pin."
```

---

## Notes for the executor

- **`./build.sh` is run as a normal user, not with sudo** — it refuses to run as root and
  calls sudo itself. It cannot be run from an agent session; ask the user.
- **Do not combine `pkill -f` with any text naming the target process.** The pattern matches
  the running command line, including inside heredocs, and kills the shell running it. This
  has happened five times in this repo. Run `pkill -x <name>` as its own command.
- If a check fails, say so with the output. A confidently-wrong "verified" claim has already
  cost this project a full debugging cycle over a reboot hang that turned out to be a
  keyboard-focus problem.
