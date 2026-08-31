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

### Changed

- `.gitignore` now excludes locally-built ISOs and screenshots.
