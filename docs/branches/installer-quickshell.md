# Branch: `installer/quickshell`

**State:** superseded — this branch's PR #11 merged into `main`, but the product
direction changed immediately after and `installer/cli-switch` (PR #12) replaces this
QML wizard with an ANSI CLI installer. `/usr/share/cyberos/installer/` and
`tests/installer-qml.bats` were removed as part of that switch. · **Owner:** edbron
**Spec:** `docs/superpowers/specs/2026-08-31-installer-quickshell.md`
**Plan:** `docs/superpowers/plans/2026-08-31-installer-quickshell.md`

## Charter

Replace the GTK4/libadwaita installer wizard (`cyberos-install-gui`, ~1100 lines of
Python) with a Quickshell/QML wizard at `/usr/share/cyberos/installer/`, so the whole
desktop — shell and installer — runs on one UI stack. The GUI contract is unchanged:
the wizard does no disk work of its own; it collects answers and runs
`sudo -n cyberos-install … --password-stdin --yes`, secrets delivered over stdin
(`Process.write()`), never argv. Page copy, validators, and the CLI argv are ported
byte-for-byte from the GTK wizard.

## What changed

| Path | Role |
|---|---|
| `profile/airootfs/usr/share/cyberos/installer/` | the wizard: shell.qml, WizState, Probe, Theme, 9 pages |
| `profile/airootfs/usr/local/bin/cyberos-install-gui` | now a 3-line sh wrapper: `exec qs -p /usr/share/cyberos/installer` (`--dry-run` → env) |
| `profile/airootfs/usr/local/bin/cyberos-install` | installed-system cleanup now also removes `/usr/share/cyberos/installer` |
| `tests/installer-qml.bats` | 17 tests: wrapper, secrets policy gates, probe pins, page strings, argv pins, guard tri-state pin |

`packages.x86_64` and `profiledef.sh` untouched; gtk4/libadwaita remain for GNOME apps.

## Process

Subagent-driven (superpowers SDD): 6 tasks, fresh implementer + independent reviewer per
task, whole-branch final review (opus), one fix wave, one scoped re-review — all findings
addressed. Full ledger: `.superpowers/sdd/2026-08-31-installer-quickshell/progress.md`
(workspace removed after merge; rulings summarized in the PR).

Notable catches by the review seats: a spawn-failure hang (Quickshell `Process` never
emits `exited` on `FailedToStart` — every Process site now carries a guarded
`onRunningChanged` fallback), and a back-navigation state desync (Loader recreation reset
page-local combo indexes while WizState kept the real answer — the disk page could
display a different disk than `--disk` would erase; unreachable in GTK where widgets
persisted). All pages now restore their widgets from WizState on load.

## Verification (2026-08-31, build-16 live ISO in QEMU)

Overlay of the branch installer delivered via cfg-ISO onto the build-16 live medium
(`OVERLAY-OK`), then driven by keyboard through the guest:

- Live desktop boots to the Quickshell bar with the gold Install button; wizard launches
  through the real user path (Super+I → `gtk-launch cyberos-install` →
  `cyberos-install-gui` → `qs -p /usr/share/cyberos/installer`).
- Guard passed on genuine live media (`/run/archiso` present → wizard renders; tri-state
  prevents any pre-check flash).
- Welcome → Disk → Mode click-through with verbatim page copy; Probe listed both virtio
  disks (`/dev/vda 20G`, `/dev/vdb 4G`) and the Mode page interpolated the chosen disk
  ("Every partition on /dev/vdb will be destroyed.").
- **Back-navigation (the final review's C1)**: selected the non-default `/dev/vdb`,
  advanced to Mode, went Back — the disk page re-displayed **/dev/vdb**, proving the
  restore-from-WizState fix on live media. Pre-fix this displayed the default disk while
  argv kept the real one.
- Account page: defaults seeded (`student`/`cyberos`), Next correctly disabled with
  empty passwords.

Not exercised in the VM this pass (session cut short by operator): timezone-combo
restore (I1), touched-seeding on re-entry (I2), and a full wizard-driven encrypted
install. I1/I2 and the guard fallback (I4) were live-verified on the host during the
fix wave (screenshots in the fix report); the argv the wizard emits is pinned
byte-for-byte by the test suite against the known-good CLI invocation that performed
the build-16 encrypted install.

The width-cap commit (`39bf895`, tiled-window layout) landed after the VM pass began:
suite-green, not yet visually confirmed in a tiled session.

Final state: 94/94 bats green, `bash -n` clean on `cyberos-install`.
