# Branch: `hardware/enablement`

**State:** merged into `main` via PR #7 · **Owner:** hardware owner · **Spec:** `docs/SPEC.md` §2
**Plan:** `docs/superpowers/plans/2026-08-30-hardware-security-baseline.md`

## Charter

Make "runs well on all machines" a testable claim. Three support tiers, a recovery path on
every one of them, and an image small enough to distribute.

## Scope

| Path | Role |
|---|---|
| `profile/packages.x86_64` | kernel set, drivers, firmware |
| `profile/efiboot/loader/entries/` | live boot entries |
| `profile/syslinux/` | BIOS boot entries |
| `profile/airootfs/usr/local/bin/cyberos-install` | installed-system boot entries |
| `build.sh` | AUR clone handling, build logging |

## What must change

1. **`linux-lts` alongside `linux`**, with a boot entry on the *installed* system. A kernel
   regression breaking a driver is the most common cause of "it worked last month", and
   without a second kernel the student's only recovery is a reinstall.
2. **A safe-graphics boot entry** — `nomodeset` plus `WLR_RENDERER_ALLOW_SOFTWARE=1`.
   Hyprland needs a working GL stack; without it the student gets a black screen and cannot
   even file a bug. This is treated as blocking.
3. **`broadcom-wl-dkms`** — common on the older Dell and Apple laptops students own, and not
   covered by `linux-firmware`.
4. **`nvidia-open-dkms` enabled**, with the Turing-and-newer limitation documented. Older
   NVIDIA cards are Tier 3.
5. **`fwupd`** — several Tier 2 laptop failures are firmware bugs with an LVFS fix.
6. ~~**The edition split.**~~ **Withdrawn after measurement.** Splitting the security-lab
   toolset out moved the image from 4.9 GiB to only 4.7 GiB — the lab tools were never the
   bulk. VS Code (1018 MiB) and OnlyOffice (1252 MiB) are. Reaching 2 GiB would have meant
   dropping those plus Firefox, both kernels' headers, the fonts, gcc and docker, which is
   not a student desktop. CyberOS ships as one image and is distributed by mirror, NAS and
   USB rather than through GitHub releases. See `docs/SPEC.md` §1.1.

## The rule that defines this branch

**A recovery path is a boot requirement, not a nicety.** A student whose GPU driver fails
or whose kernel regressed must still be able to reach a shell — someone who cannot boot
cannot file a bug. Safe graphics and the LTS kernel entry are therefore blocking, and both
must exist on the *installed* system, not only the live image.

## Untested territory

The test matrix has one populated cell: UEFI × virtual disk × QEMU. BIOS/CSM boot is
configured in `profiledef.sh` and has never been booted. Real USB on real hardware has never
been tested. Both are this branch's responsibility.
