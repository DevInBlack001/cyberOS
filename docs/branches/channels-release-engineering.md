# Branch: `channels/release-engineering`

**State:** planned · **Owner:** release engineer · **Spec:** `docs/SPEC.md` §4
**Plan:** `docs/superpowers/plans/2026-08-30-release-channels.md`

## Charter

Give the department control over when student machines change. Arch is rolling; a lab of
40 machines must not be.

## The model in one paragraph

A channel is a **date**. Student machines point `[core]` and `[extra]` at a dated snapshot
in the Arch Linux Archive instead of a rolling mirror, so `pacman -Syu` produces the same
system on every machine until a maintainer moves the date. `unstable` tracks today,
`testing` advances weekly, `stable` advances monthly after the full test matrix passes.
Security fixes bypass the pin through a higher-precedence `[cyberos-security]` repository.

## Scope

| Path | Role |
|---|---|
| `profile/airootfs/usr/local/bin/cyberos-channel` | read, set, and freeze the channel pin |
| `profile/airootfs/etc/pacman.d/cyberos-channel` | the one-line pin |
| `profile/airootfs/etc/pacman.conf` | repo precedence order |
| `tools/promote-channel.sh` | maintainer-side promotion |
| `tools/security-backport.sh` | copy one CVE-fixed package into `[cyberos-security]` |

## The rules that define this branch

- **`[cyberos-security]` is for CVEs only.** Every commit adding a package to it must cite
  a CVE or Arch AVG identifier. It is not a route for slipping features past the schedule.
- **An entry leaves `[cyberos-security]` once the pin advances past it.** Otherwise the
  repo quietly becomes a fork of Arch.
- **A CVSS ≥ 7.0 fix ships within 72 hours** of the Arch Security Advisory.
- **Moving a channel backwards is a downgrade** and must require `pacman -Syuu` plus
  explicit confirmation.

## Do not

- Mirror `core` and `extra`. That is ~80 GiB to host and keep in sync, and the Arch Linux
  Archive already is that mirror, dated daily and public.
- Point students straight at `archive.archlinux.org` for a whole campus without a caching
  proxy in front of it (§4.5). It is one host and was not built for that load.
