# Branch: `docs/spec`

**State:** open · **Owner:** @edbron

## Charter

The normative specification and the branch charters. This branch adds no code and changes
no behaviour — it writes down the standards the rest of the work is measured against, so
that "is this ready to release?" has an answer other than someone's judgement on the day.

## Scope

| Path | Role |
|---|---|
| `docs/SPEC.md` | the specification: hardware tiers, release channels, app store, security |
| `docs/branches/` | one charter per branch, including this one |
| `docs/superpowers/plans/` | the implementation plans the spec implies |

## What it establishes

- **Hardware support tiers** replacing "runs on all machines". Only Tier 1 gates a release.
- **A channel is a date.** Delayed rolling via dated Arch Linux Archive snapshots, with
  `[cyberos-security]` overriding the pin for CVE fixes.
- **Nine automated gates plus two reviews** before anything reaches the app store.
- **Release criteria and a test matrix** — the matrix currently has one populated cell.

## The rule that defines this branch

**Nothing here describes behaviour that does not exist without saying so.** Where the spec
records an aspiration rather than a fact it says which, and where a requirement has no plan
behind it that is stated too. A specification that quietly describes the system you wanted
is worse than no specification, because people then build against it.

Known deviations recorded rather than papered over:

- UAPI.1 Boot Loader Specification is **not met**. The installer uses GRUB, because GRUB is
  what gives us UEFI and legacy BIOS from one bootloader plus `os-prober` for dual-boot.
  GRUB does not emit Type #1 entries.
- Reproducible builds reach SLSA L1 only (`SOURCE_DATE_EPOCH` is set). `BUILDINFO` capture
  and `rebuilderd` are deferred until decisions D1 and D2 are answered.

## Blocking decisions this branch surfaces

`docs/SPEC.md` §9 lists four. D1 (repository hosting) and D2 (signing key custody) block
publishing anything; the app-store plan cannot finish without them.
