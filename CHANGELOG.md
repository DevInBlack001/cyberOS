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

### Removed

- `kvantum`: an orphan left behind by the Quickshell-only migration above.
  It styled the KDE app suite that migration removed; nothing else in the
  image sets a Kvantum style or references it, and the `pixie` SDDM theme
  (the one remaining Qt greeter) is a self-contained QtQuick theme with no
  Kvantum dependency, confirmed by its package metadata and QML source.
- `qt5ct` and its skel config: `QT_QPA_PLATFORMTHEME` is only ever set to
  `qt6ct`, so Qt5 apps (wireshark-qt is the one left on the ISO) never
  picked up the qt5ct scheme in the first place: it was configured but
  never wired in. Qt6 apps keep working exactly as before through qt6ct,
  which `cyberos-theme` actively toggles on light/dark switches.
