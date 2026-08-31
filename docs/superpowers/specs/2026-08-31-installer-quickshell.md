# CyberOS Installer in Quickshell — Spec

**Date:** 2026-08-31 · **Owner:** edbron · **Branch:** `installer/quickshell`
**User decision:** convert the GTK4/libadwaita wizard to Quickshell/QML.

## Why
The desktop shell is now Quickshell (QML); the installer is the last GTK4/libadwaita
surface. Converting unifies the look and drops the GNOME toolkit from CyberOS's own
code. NOTE: `gtk4`/`libadwaita`/`python-gobject` STAY in the image — gnome-calculator,
gnome-text-editor and gnome-disk-utility need them; only CyberOS's wizard changes.
Swapping those apps is out of scope.

## The one rule (unchanged from the GTK wizard)
**The GUI performs no disk work.** It collects answers and runs
`sudo -n /usr/local/bin/cyberos-install` with the same flags as before, secrets over
stdin (user password, root blank line, optional LUKS passphrase — never argv).

## What ships
- `/usr/share/cyberos/installer/` — a Quickshell config: `shell.qml` (ShellRoot +
  FloatingWindow "Install CyberOS", 720×560, Back/Next header), page files, a
  `WizState` singleton (all answers), a `Probe` singleton (system queries via
  Process), its own `Theme.qml` reading `~/.config/quickshell/theme.json` with the
  standard dark fallback (deliberate small duplication of the shell's Theme; the
  installer must render even if the shell config is absent).
- `/usr/local/bin/cyberos-install-gui` becomes a 3-line sh wrapper:
  `--dry-run` → env `CYBEROS_INSTALLER_DRYRUN=1`, then `exec qs -p /usr/share/cyberos/installer`.
  Everything that launches the wizard (.desktop, Super+I, the bar button, the
  installer's self-cleanup sed) keeps working unchanged.
- The GTK wizard file is deleted.

## Behaviour parity checklist (each is a requirement)
Pages welcome → disk → mode → custom(manual only) → account → options → confirm →
install → done, with: dry-run banner; disk list from `lsblk -dnpo NAME,SIZE,TYPE,MODEL`
minus `NOT_A_TARGET` `^/dev/(zram|loop|ram|sr|fd)\d` and the live medium
(`findmnt /run/archiso/bootmnt` → PKNAME); erase/alongside/manual with the alongside
25 GiB `sgdisk -F/-E` gate and hint texts; manual partition pickers defaulting ESP by
PARTTYPENAME and root ≠ ESP, format-EFI switch, root=EFI validation; account
validation (`[a-z_][a-z0-9_-]*`, non-empty matching passwords, non-empty hostname);
timezone list from `timedatectl list-timezones` (fallback UTC/Africa/Accra, default
Africa/Accra), ext4/btrfs, swap 0–64 default 4; LUKS switch with confirmed ≥8-char
passphrase; summary + "I understand" gate; streaming install log with failed state and
Close; done page with "Restart now" (`sudo -n systemctl reboot`); the
`/run/archiso` guard dialog when not on live media (unless dry-run).
argv exactly as the GTK wizard built it, `--password-stdin --yes` last.

## Constraints
- Quickshell 0.3.1 API; `Process.write()` for stdin secrets MUST be verified in the
  qmltypes before use — if absent, STOP: secrets may never pass through a shell line.
- Theme tokens only (no hex outside the Theme fallback), glyphs as `\uXXXX`,
  software-rendering safe. QtQuick.Controls allowed (qt6-declarative ships it).
- `profiledef.sh`'s existing 755 entry for `/usr/local/bin/cyberos-install-gui`
  still applies (path unchanged).
