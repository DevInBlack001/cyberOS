# Branch: `hardware/enablement`

**State:** planned · **Owner:** hardware owner · **Spec:** `docs/SPEC.md` §2
**Plan:** `docs/superpowers/plans/2026-08-30-hardware-security-baseline.md`

## Charter

Make "runs well on all machines" a testable claim. Three support tiers, a recovery path on
every one of them, and an image small enough to distribute.

## Scope

| Path | Role |
|---|---|
| `profile/packages.x86_64` | kernel set, drivers, firmware |
| `profile/packages.base.x86_64` / `packages.lab.x86_64` | edition split |
| `profile/efiboot/loader/entries/` | live boot entries |
| `profile/syslinux/` | BIOS boot entries |
| `profile/airootfs/usr/local/bin/cyberos-install` | installed-system boot entries |
| `build.sh` | `--edition base|lab` |

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
6. **The edition split.** The image is 4.9 GiB and cannot be a GitHub release asset
   (2 GiB cap). `cyberos-base` must fit under 2.0 GiB; `cyberos-lab` keeps the full offline
   toolset for classroom USBs.

## The rule that defines this branch

**Both editions build from one `profile/`.** The difference is a package list selected by a
build flag. Two profiles would drift, and the drift would only show up on a student's
machine.

## Untested territory

The test matrix has one populated cell: UEFI × virtual disk × QEMU. BIOS/CSM boot is
configured in `profiledef.sh` and has never been booted. Real USB on real hardware has never
been tested. Both are this branch's responsibility.
