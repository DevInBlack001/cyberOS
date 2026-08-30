# Branch: `installer/gui`

**State:** merged into `main` via PR #2 · **Owner:** @edbron

## Charter

The graphical install experience: clicking **Install CyberOS** walks a student through a
wizard instead of dropping them at a shell.

## Scope

| Path | Role |
|---|---|
| `profile/airootfs/usr/local/bin/cyberos-install-gui` | GTK4/libadwaita wizard, ~420 lines of Python |
| `profile/airootfs/usr/local/bin/cyberos-install` | The CLI that does all disk work |
| `profile/airootfs/usr/share/applications/cyberos-install.desktop` | Launcher |
| `profile/packages.x86_64` | `python-gobject`, `gtk4`, `libadwaita` only |

## The rule that defines this branch

**The GUI performs no disk operations.** It collects answers and shells out to
`cyberos-install` with flags. There is exactly one implementation of partitioning,
formatting, `pacstrap` and bootloader installation, and the GUI and CLI therefore cannot
drift apart. Any PR that adds `sgdisk`, `mkfs`, or `pacstrap` to the GUI is rejected on
sight; add the flag to the CLI instead.

## What was delivered

- Pages: welcome → disk → mode → custom → account → options → confirm → install → done
- Three modes: **erase** the disk, install **alongside** an existing OS in free space, or
  **custom** partition selection
- Filesystems: ext4 and btrfs
- `--dry-run` clicks the whole wizard through with no live medium and no disk touched
- The wizard reads `~/.config/cyberos/mode` and matches the desktop's light/dark setting

## Traps this branch already hit

- **`/dev/zram0` was offered as an install target and default-selected.** `lsblk` reports
  zram as `TYPE=disk`. Guard with the `NOT_A_TARGET` regex *and* the live-medium exclusion;
  do not remove either.
- **Passwords must go over stdin** (`--password-stdin`). `argv` is world-readable through
  `/proc/*/cmdline`.
- **`self.index = 0` must be set before pages are built.** A radio's `toggled` handler fires
  during construction and calls `sync_buttons()`.
- **`Adw.Clamp` made the disk page worse** — a long model string in a `DropDown` suffix
  squeezed the row title to one character. `Adw.ComboRow` with shortened labels, clamp 600.
- Driving the wizard's text entries through QEMU `sendkey` is unreliable; focus does not
  land in password fields. Test the GUI by hand, and the install path through the CLI.

## Follow-up work

- LUKS2 full-disk encryption (`docs/SPEC.md` S3) — belongs here
- A GRUB dual-boot menu entry has never been verified, because the "existing OS" used in
  testing was a bare ext4 partition with nothing for `os-prober` to find
