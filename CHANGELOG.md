# Changelog

All notable changes to CyberOS are documented in this file, starting from this
file's introduction. Earlier history is in `git log`, not backfilled here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows CyberOS's own scheme (`docs/SPEC.md` §4.6): `vYYYY.MM` for a
stable snapshot, `build-NN` for an engineering build, `YYYY.MM.DD` as the ISO's
own build metadata — not SemVer.

## [Unreleased]

### Security

- Fixed a shell injection in `cyberos-install`'s chroot handoff: an unquoted
  heredoc let a crafted `--user`/`--password`/`--root-password` value (a
  quote, backtick, or `$(...)`) run as arbitrary shell code, as root, inside
  `arch-chroot`. Tainted values now cross into the chroot via `env` instead
  of host-side text interpolation.
- Added `--user` character-set validation and an 8-character minimum for
  `--encrypt` passphrases to the CLI installer path (the GUI already
  enforced both); `--password` (argv) now warns that `--password-stdin` is
  safer.
- Quickshell bar chips that render text this desktop does not control
  (MPRIS track metadata, a window's own title) now render as plain text
  instead of Qt's default auto-detected rich text, closing a markup
  injection into the system bar.
- `cyberos-install`'s unattended `--disk` path had no validation at all: a
  typo like `--disk /dev/sda1` instead of `/dev/sda` ran `wipefs`/
  `sgdisk -Z` against a partition. `is_whole_disk` now rejects anything
  that is not `lsblk`'s `TYPE=disk`, mirroring a check the interactive
  wizard already had for its own disk-selection path.
- `unmount_disk` swallowed every `umount` failure unconditionally and had
  no way to report one, so a genuinely busy partition (a stale LUKS
  mapping from a prior encrypted install, say) fell straight through into
  `wipefs`/`sgdisk -Z` regardless, silently "handled", still broken. It
  now verifies nothing is left mounted afterward and the installer dies
  with a clear message instead of proceeding.
- The pre-partition disk-mounted guard matched only a raw partition device
  path in `/proc/mounts`, so a previous *encrypted* CyberOS install left
  unlocked and mounted (source `/dev/mapper/<name>`, never the partition
  path underneath it) was invisible to it. Replaced with `disk_has_mount`,
  which follows `lsblk`'s own device-dependency walk and so also covers a
  mapper device stacked on one of the disk's partitions.
- The QML file manager's "Extract" ran `7z x` directly against whatever
  archive was selected, trusting the extractor's own (version-dependent)
  defenses against a path-traversal entry writing outside the target
  directory. Archives are exactly the kind of file this project's own
  users handle routinely (CTF challenges, malware samples, coursework
  downloads). It now lists the archive first and refuses to extract
  anything containing a `..` segment or an absolute entry path.

### Fixed

- `cyberos-install`'s erase mode failed with a raw kernel I/O error partway
  through partitioning, reported from real hardware testing. Root cause: a
  disk carrying a previous CyberOS install (recognizable `CYBEROS`/
  `CYBEROS_EFI` labels) is exactly what this project's own udisks2
  auto-mount picks up as soon as the live session starts, and the installer
  never unmounted anything beyond its own `/mnt` and a blanket `swapoff -a`
  before handing the disk to `wipefs`/`sgdisk -Z`. A still-mounted partition
  makes both fail. `unmount_disk` now runs before partitioning in every mode
  (erase, manual, alongside), not just the one that reproduced the bug.

### Added

- `cyberos-arch-audit.timer`/`.service`: a weekly `arch-audit` run on
  installed systems, reporting known CVEs in installed packages against
  the pinned channel to the journal (`docs/SPEC.md` S4). Enabled by the
  installer alongside NetworkManager/sddm/bluetooth/cyberos-firstboot.

### Changed

- GTK/GNOME apps removed; Qt6/KDE suite in their place: dolphin (files), ark
  (archives), okular (PDF), gwenview (images), kate (editor), kcalc,
  partitionmanager, pavucontrol-qt. Portal FileChooser now served by
  xdg-desktop-portal-kde.
- nm-applet, nm-connection-editor and blueman replaced by native Quickshell
  panels: `qs ipc call wifi toggle` / `qs ipc call bt toggle`, wired to the
  bar's network and bluetooth chips.
- Launcher (Super+D) groups apps into category chips: Security, Development,
  Internet, Office, Graphics, Media, System, Utilities. Tab cycles groups.
  Metasploit gets a Security launcher entry; Wireshark/Ghidra are re-grouped
  into Security.
- cyberos-theme now flips GTK3 settings.ini and the qt6ct palette instead of
  gsettings; light mode reaches Qt apps for the first time.
- `build.sh` now asks (once the ISO is built) whether to delete `work/` --
  the AUR build trees and mkarchiso's scratch dir, which can run several GB
  and were previously left on disk indefinitely. `--keep-work`/`--purge-work`
  skip the prompt for non-interactive use; `repo/` and `out/` are untouched
  either way.
- `.gitignore` now excludes locally-built ISOs and screenshots.
- `docs/SPEC.md` §7.2's requirement table now tracks implementation status
  per item (S1-S6), instead of leaving "is this actually done" unanswered.
- Caught up `docs/branches/` to actual merge history: several charters
  still said "planned"/"open" for branches merged weeks ago, two merged
  branches had no table row at all, and `main.md` flagged an already-fixed
  bug as outstanding.
- The desktop is Quickshell-only: dolphin, gwenview, okular, kate, kcalc, ark,
  partitionmanager and pavucontrol-qt are gone, replaced by three native QML
  surfaces — Files (Super+E), Images, and a Pipewire Mixer on the bar's audio
  chip. Firefox (which is also the PDF viewer) and VS Code stay; so does the
  headless xdg-desktop-portal-kde, purely as the file-dialog backend.
- Added xdg-utils and trash-cli: the QML file manager opens files through
  xdg-open and deletes through trash-put, never rm.
