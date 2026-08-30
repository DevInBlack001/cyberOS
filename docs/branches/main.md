# Branch: `main`

**State:** protected · **Owner:** @edbron

## What it is

The releasable trunk. Every tagged build (`build-11`, `build-12`, `v2026.MM`) comes from a
commit on `main`. A student who clones this repo and runs `./build.sh` must get an ISO
that meets the release criteria in `docs/SPEC.md` §6.1.

## Rules

- **No direct pushes.** Branch protection is on. Everything arrives via pull request with
  at least one approving review from the CODEOWNERS owner of every path touched.
- Every merge must leave `main` in a state where `./build.sh` succeeds. If you cannot build
  it, it does not merge.
- Tags are cut from `main` only.
- Commit authorship uses `edbron <edbron411@gmail.com>`. The repo has a local
  `git config user.email`; do not override it.

## What lives here

Everything. `main` is the union of all merged branches:

```
build.sh  test-vm.sh          # build and QEMU test drivers
aur/                          # AUR package list + licensed .deb drop point
assets/                       # wallpaper sources (SVG)
docs/                         # SPEC.md, branches/, plans
profile/                      # the archiso profile — the actual OS
tools/                        # release tooling (arrives with channels/ and packages/)
```

## Release procedure

1. Confirm the working tree is clean and `main` is up to date.
2. `sudo ./build.sh` — must be run by a human; `sudo` cannot be driven from an agent session.
3. Run the §6.2 test matrix. Every Tier 1 cell must pass.
4. `git tag build-NN` for an engineering build, `git tag v2026.MM` for a stable snapshot.
5. Push the tag. Attach `cyberos-base` to the GitHub release; `cyberos-lab` exceeds
   GitHub's 2 GiB asset cap and goes to the campus mirror.

## Known outstanding work on `main`

- Uncommitted fix in the working tree: `cyberos-theme` must write the **active** palette to
  both foot `[colors-light]` and `[colors-dark]` sections. Splitting them lets foot pick via
  the appearance portal, which defaults to dark when no portal runs, so terminals opened
  after switching to light came up dark. Verified on the host; not yet verified in a VM.
- No install has been run from build #13.
