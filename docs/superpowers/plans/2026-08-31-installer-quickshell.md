# Installer-in-Quickshell Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the GTK4/libadwaita installer wizard with a Quickshell/QML one at exact behaviour parity, still a pure front-end over the `cyberos-install` CLI.

**Architecture:** A standalone Quickshell config at `/usr/share/cyberos/installer/` run via `qs -p` from a 3-line wrapper at the old `/usr/local/bin/cyberos-install-gui` path (so every launcher keeps working). A `WizState` singleton holds all answers; a `Probe` singleton does the system queries (lsblk/findmnt/sgdisk/timedatectl) through `Process`; `shell.qml` hosts a `FloatingWindow` with the Back/Next frame and a page `StackView`-style Loader; page files mirror the GTK pages one-to-one. Secrets go to the CLI's stdin via `Process.write()` — never argv, never a shell line.

**Tech Stack:** quickshell 0.3.1 (`ShellRoot`, `FloatingWindow`, `Quickshell.Io.Process/SplitParser/StdioCollector`, `IpcHandler` not needed), QtQuick + QtQuick.Controls (qt6-declarative), bats 1.14 static tests, the session's QEMU harness for the VM task.

**Spec:** `docs/superpowers/specs/2026-08-31-installer-quickshell.md`

## Global Constraints

- Branch `installer/quickshell` off current `main`. Author `edbron <edbron411@gmail.com>` (repo-local identity).
- **The GUI performs no disk work** — it builds exactly this argv (order fixed, from the GTK wizard verbatim): `sudo -n /usr/local/bin/cyberos-install --disk <disk> [--root <p> --efi <p> [--format-efi] | --alongside | --erase] --user <u> --hostname <h> --tz <z> --fs <ext4|btrfs> --swap <n> [--encrypt] --password-stdin --yes` and writes stdin lines: user password, empty (root=same), optional LUKS passphrase.
- **Secrets never touch argv or any shell string.** `Process.write()` must be verified present in `/tmp/claude-1000/-home-edbron-Work/9fdca27c-4540-4321-9795-683d0bdd0a18/scratchpad/qs/usr/lib/qt6/qml/Quickshell/Io/quickshell-io.qmltypes` in Task 1; if it does not exist, report BLOCKED — do not improvise a pipe through `sh -c`.
- Behaviour parity checklist in the spec is the requirement set; the GTK source (git: `profile/airootfs/usr/local/bin/cyberos-install-gui` at the branch point) is the reference implementation — port its logic, constants and copy text faithfully (exact regexes `^/dev/(zram|loop|ram|sr|fd)\d` and `[a-z_][a-z0-9_-]*`, the 25 GiB gate, hint texts, defaults student/cyberos/Africa da Accra→`Africa/Accra`/ext4/swap 4).
- Theme tokens only (`Theme.*`; no hex in QML outside the installer Theme.qml's fallback object); glyphs `\uXXXX` escapes only; software-rendering safe (no ShaderEffect). These are gated by the existing policy tests only for the shell dir — Task 1 adds equivalents for the installer dir.
- Test runner: `<scratchpad>/bats-core/bin/bats` (`/tmp/claude-1000/-home-edbron-Work/9fdca27c-4540-4321-9795-683d0bdd0a18/scratchpad/bats-core/bin/bats`); full `tests/` green before every commit.
- Host smoke: `CYBEROS_INSTALLER_DRYRUN=1 qs -p profile/airootfs/usr/share/cyberos/installer` with `QML2_IMPORT_PATH=<scratchpad>/qs/usr/lib/qt6/qml` and the qs binary from `<scratchpad>/qs/usr/bin/qs`. A FloatingWindow is a normal toplevel, so `grim` MAY work here (unlike layer surfaces) — try it; if it hangs, kill grim and fall back to `hyprctl clients -j` + zero-warning logs. Kill leftovers with `pkill -x qs` ONLY (NEVER `pkill -f` — it kills your own shell).
- `packages.x86_64` is NOT touched (gtk4/libadwaita/python-gobject stay for the GNOME apps). `profiledef.sh` is NOT touched (the wrapper keeps the old path's 755 entry).

## File Structure

Under `profile/airootfs/usr/share/cyberos/installer/`:

| File | Responsibility |
|---|---|
| `shell.qml` | ShellRoot + FloatingWindow(720×560, "Install CyberOS") + header (Back/Next) + page Loader + navigation/skip logic + the `/run/archiso` guard |
| `Theme.qml` + `qmldir` | palette from `~/.config/quickshell/theme.json`, watched, dark fallback (installer-local copy, deliberate) |
| `WizState.qml` (qmldir singleton) | every answer: disk, mode, custom parts, account, tz/fs/swap, encrypt+passphrases, dryRun; `argv()` and `stdinSecrets()` builders |
| `Probe.qml` (qmldir singleton) | `disks` model, `liveMedium`, `freeSpaceGib(disk, cb)`, `partitions(disk, cb)`, `timezones` — all via Process |
| `pages/WelcomePage.qml` … `pages/DonePage.qml` | one file per page, logic ported from the GTK page functions |
| `pages/Field.qml`, `pages/Hint.qml` | shared themed form row + hint label |
| Modify: `profile/airootfs/usr/local/bin/cyberos-install-gui` | becomes the sh wrapper |
| Test: `tests/installer-qml.bats` | policy + parity pinning |

---

### Task 1: Skeleton — wrapper, window, theme, navigation, dry-run smoke

**Files:** Create `shell.qml`, `Theme.qml`, `qmldir`, `WizState.qml`, `pages/WelcomePage.qml`, `pages/DonePage.qml`; rewrite `/usr/local/bin/cyberos-install-gui` as the wrapper; Test `tests/installer-qml.bats`.

**Interfaces produced:** `WizState` properties `dryRun` (bool, from `Quickshell.env("CYBEROS_INSTALLER_DRYRUN")` truthiness — remember env() returns null), page order list `["welcome","disk","mode","custom","account","options","confirm","install","done"]`, `skipped(name)` (custom unless mode==="manual"); shell.qml exposes `nextEnabled`/`nextLabel` via the current page item's properties (`property bool ready: true`, `property string nextLabel: "Next"` convention every page follows); Theme identical property list to the desktop shell's Theme.

- [ ] **Step 1 (verify before anything):** `grep -A3 'name: "write"' <scratchpad>/qs/usr/lib/qt6/qml/Quickshell/Io/quickshell-io.qmltypes` and confirm a `write(...)` method on Process (search the Process component block). Absent → BLOCKED.
- [ ] **Step 2: failing tests** — `tests/installer-qml.bats`:

```bash
#!/usr/bin/env bats
ROOT="$BATS_TEST_DIRNAME/.."
INST="$ROOT/profile/airootfs/usr/share/cyberos/installer"
QMLLINT=/usr/lib/qt6/bin/qmllint

@test "installer config exists with wrapper, and the GTK wizard is gone" {
  [ -f "$INST/shell.qml" ]
  head -1 "$ROOT/profile/airootfs/usr/local/bin/cyberos-install-gui" | grep -q '^#!/bin/sh'
  grep -q 'CYBEROS_INSTALLER_DRYRUN' "$ROOT/profile/airootfs/usr/local/bin/cyberos-install-gui"
  grep -q 'exec qs -p /usr/share/cyberos/installer' "$ROOT/profile/airootfs/usr/local/bin/cyberos-install-gui"
  ! grep -q 'import gi' "$ROOT/profile/airootfs/usr/local/bin/cyberos-install-gui"
}

@test "installer QML: no raw glyphs, no hex outside Theme.qml, parses" {
  ! grep -rlP '[\x{E000}-\x{F8FF}\x{F0000}-\x{FFFFD}]' "$INST" --include='*.qml'
  run grep -rlE "['\"]#[0-9A-Fa-f]{3,8}" "$INST" --include='*.qml'
  [ "$output" = "$INST/Theme.qml" ] || [ -z "$output" ]
  [ -x "$QMLLINT" ] || skip "qmllint absent"
  find "$INST" -name '*.qml' -print0 | xargs -0 -n1 "$QMLLINT" --bare -I /tmp/claude-1000/-home-edbron-Work/9fdca27c-4540-4321-9795-683d0bdd0a18/scratchpad/qs/usr/lib/qt6/qml
}

@test "env guard uses truthiness, never !== empty-string" {
  ! grep -rn 'env("[A-Z_]*") !==' "$INST"
}
```

(Delete of the GTK python happens in Task 5 when parity is complete; until then the wrapper replaces it — so the "GTK wizard is gone" assertion here checks the *wrapper file*, and Task 5's test checks nothing python remains.)
- [ ] **Step 3:** RED run. **Step 4:** implement: wrapper `#!/bin/sh` — `case "$1" in --dry-run) CYBEROS_INSTALLER_DRYRUN=1; export CYBEROS_INSTALLER_DRYRUN;; esac; exec qs -p /usr/share/cyberos/installer`; `shell.qml` FloatingWindow with header Rectangle (Back/Next Buttons themed via Theme), a `Loader` swapping `pages/<Name>Page.qml` by index with the skip rule, welcome and done pages ported (copy text verbatim incl. the DRY RUN banner and "Restart now" → `Quickshell.execDetached(["sudo","-n","systemctl","reboot"])`); the `/run/archiso` guard: in shell.qml `Component.onCompleted`, if `!WizState.dryRun` and a `Process { command: ["test","-d","/run/archiso"] }` exits non-zero, swap the window content to the "CyberOS is already installed" message (copy text from the GTK dialog).
- [ ] **Step 5:** GREEN + full suite. **Step 6:** host dry-run smoke (launch line in Global Constraints; LOOK at it if grim cooperates — FloatingWindow is a normal window, try `grim` with the window's geometry from `hyprctl clients`). **Step 7:** commit `"installer: quickshell skeleton behind the old launcher path"`.

### Task 2: Probe singleton — disks, live medium, free space, partitions, timezones

**Files:** Create `Probe.qml` (+qmldir line); extend `tests/installer-qml.bats`.
**Interfaces produced:** `Probe.disks` (list of `{name,size,model,label}`), `Probe.ready` (bool), `Probe.liveMedium` (string|""), `Probe.timezones` (list, `/`-containing only, fallback `["UTC","Africa/Accra"]`), `Probe.freeSpaceGib(disk, function(gib))`, `Probe.partitions(disk, function(list of {dev,size,fstype,ptype,label}))`.

- [ ] Tests (append; static pinning of the ported constants):

```bash
@test "probe ports the exact exclusion and commands" {
  grep -q 'zram|loop|ram|sr|fd' "$INST/Probe.qml"
  grep -q 'lsblk.*-dnpo.*NAME,SIZE,TYPE,MODEL' "$INST/Probe.qml"
  grep -q 'findmnt.*-no.*SOURCE.*/run/archiso/bootmnt' "$INST/Probe.qml"
  grep -q 'sgdisk' "$INST/Probe.qml"
  grep -q 'timedatectl' "$INST/Probe.qml"
  grep -qE 'PKNAME' "$INST/Probe.qml"
}
```

- [ ] Implement by porting `list_disks`/`live_medium`/`free_space_gib`/`partitions`/`timezones` logic: each a `Process` + `StdioCollector`; disk labels formatted as the GTK code did (`name  (size)  model[:22]`); free-space maths `max(0, (last-first+1)*512 / 2^30)` floored; callbacks because Process is async — chain live-medium before disks (disks filter needs it). Smoke: dry-run launch on the host must list the host's real disks (visually or via a temporary `console.log` removed before commit). Commit `"installer: system probes ported to QML"`.

### Task 3: Disk + mode pages with the alongside gate

**Files:** Create `pages/DiskPage.qml`, `pages/ModePage.qml`, `pages/Field.qml`, `pages/Hint.qml`; extend tests.
**Interfaces:** consumes Probe + WizState; produces `WizState.disk`, `WizState.mode` ("erase"|"alongside"|"manual", default "erase"), `WizState.freeGib` (updated on mode/disk change); ModePage `ready` false when alongside && freeGib<25.

- [ ] Tests: pin the three mode keys + hint strings:

```bash
@test "mode page ports the three modes and the 25 GiB gate" {
  for s in 'Install alongside' 'Erase the whole disk' 'Custom partitioning' '25' 'gparted' 'will be destroyed'; do
    grep -qF "$s" "$INST/pages/ModePage.qml"
  done
}
```

- [ ] Implement: DiskPage = themed ComboBox (QtQuick.Controls, styled with Theme colors) of `Probe.disks` labels, subtitle copy "The entire disk will be erased"; ModePage = three radio rows (Rectangle+MouseArea or RadioButton restyled) with the exact titles/subtitles, hint label under them fed by the ported `refresh_mode_hint` strings, `Probe.freeSpaceGib` call on selection. Smoke + commit `"installer: disk and mode pages"`.

### Task 4: Custom, account and options pages with validators

**Files:** Create `pages/CustomPage.qml`, `pages/AccountPage.qml`, `pages/OptionsPage.qml`; extend tests.
**Interfaces:** produces `WizState.{rootPart,efiPart,formatEfi,user,host,password,tz,fs,swapGib,encrypt,luksPass}`; each page exposes `ready` implementing the ported validators (`validate_custom`: parts exist && root!==efi; `validate_account`: regex/user, non-empty pw, pw match, non-empty host; `validate_encryption`: off || (non-empty && match && len>=8)) and shows the exact hint strings.

- [ ] Tests:

```bash
@test "validators port the exact rules and messages" {
  grep -qF '[a-z_][a-z0-9_-]*' "$INST/pages/AccountPage.qml"
  grep -qF 'Passwords do not match' "$INST/pages/AccountPage.qml"
  grep -qF 'must be different partitions' "$INST/pages/CustomPage.qml"
  grep -qF 'at least 8 characters' "$INST/pages/OptionsPage.qml"
  grep -qF 'Africa/Accra' "$INST/pages/OptionsPage.qml"
}
```

- [ ] Implement: CustomPage refreshed on entry via `Probe.partitions` (ESP preselect by `ptype` containing "EFI", root defaults to first non-ESP index); Account defaults student/cyberos; Options: tz ComboBox (default Africa/Accra when present), ext4/btrfs, SpinBox 0–64 default 4, encrypt switch enabling two passphrase fields (cleared when switched off). TextField `echoMode: TextInput.Password` for all secret fields. Smoke + commit `"installer: custom, account and options pages"`.

### Task 5: Confirm, install (streaming + secrets), done — and the GTK file's deletion

**Files:** Create `pages/ConfirmPage.qml`, `pages/InstallPage.qml`; extend `WizState` with `argv()`/`stdinSecrets()`; the wrapper already exists — now DELETE the python content is already gone (wrapper replaced it in T1) so this task's deletion assertion is: nothing GTK remains anywhere; extend tests.
**Interfaces:** `WizState.argv()` returns the exact list from Global Constraints; `WizState.stdinSecrets()` returns `password + "\n" + "\n" (+ luksPass + "\n" if encrypt)`.

- [ ] Tests:

```bash
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
```

- [ ] Implement: ConfirmPage = ported summary lines + "I understand" CheckBox gating `ready`, Next label "Install"; InstallPage = read-only log (`TextArea` or Flickable+Text) fed by `Process { command: WizState.argv(); stdout: SplitParser { onRead: append } ; stderr merged via `stderr: SplitParser` appending to the same log }`, `onStarted: { write(WizState.stdinSecrets()); stdinEnabled = false }` (close stdin after writing — check the qmltypes for the close idiom: setting `stdinEnabled: false` flushes+closes per upstream docs; verify at runtime), exit code → done page or failed state with the ported failure text and a Close button; dry-run prints the quoted command + "(password supplied on stdin, not on the command line)" and jumps to done. Smoke: full dry-run click-through on the host (keyboard: Tab/Enter — FloatingWindow takes normal keyboard focus). Commit `"installer: streaming install page; GTK wizard fully replaced"`.

### Task 6: VM verification (controller-run)

Boot the build-16 live ISO in the established harness; the new installer files ride a cfg ISO (`xorriso` + `-cdrom`, mount+copy over /usr/share/cyberos/installer and the wrapper). Verify: wizard opens from the bar button (gold Install), themed dark; full dry-run click-through via sendkey (chunked type.sh; screenshot each page); then a REAL encrypted install driven through the wizard UI as far as sendkey allows — if GUI text entry proves unreliable (it has before), fall back to asserting the argv line in dry-run matches the known-good CLI invocation byte-for-byte and run the actual install via the CLI as prior passes did, recording the substitution honestly. Record results in `docs/branches/installer-quickshell.md`, push, PR.

## Self-Review
- Spec coverage: every checklist item mapped (welcome/dry-run T1, guard T1, disks/probe T2, disk+mode+gate T3, custom/account/options+validators T4, confirm/install/done+argv+secrets T5, VM T6). Packages/profiledef untouched per spec — no task touches them. ✓
- Placeholders: none; every step carries code or exact commands. The one deliberate deferral (Process stdin close idiom) is a named runtime verification with a fallback instruction, not a TBD. ✓
- Type consistency: WizState property names identical across T3/T4/T5; page `ready`/`nextLabel` convention set in T1 and used by every page; Probe callback signatures consistent. ✓
- Known risks, stated: FloatingWindow-under-ShellRoot as an app window (T1 smoke proves or blocks); Process.write existence (T1 step 1); GUI-driven text entry in the VM (T6 has the honest fallback).
