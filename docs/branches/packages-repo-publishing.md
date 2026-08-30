# Branch: `packages/repo-publishing`

**State:** open on origin. PR #1 was **closed without merging.** · **Owner:** @edbron

## Charter

Publish the department's own signed pacman repository, so that the packages CyberOS ships
can be updated after install instead of being frozen at ISO build time.

## Why the PR was closed

The branch is sound but it landed before the surrounding decisions were made. It is now
superseded in scope by `docs/SPEC.md` §5 and by the `store/app-market` branch: the
repository is not just a publishing target, it is the back end of a reviewed app store.

The work here is not wasted — `tools/release.sh` and the PKGBUILD template are the
foundation the store builds on. Rebase this branch onto `main`, narrow it to the
publishing pipeline, and let `store/app-market` add the submission and review layer.

## Scope

| Path | Role |
|---|---|
| `tools/release.sh` | builds `packages/`, signs, stages `dist/cyberos-repo/x86_64/` |
| `packages/template/PKGBUILD` | template for a department package |
| `profile/airootfs/etc/pacman.conf` | client repo configuration |
| `build.sh` | hook to build department packages |

`tools/release.sh` refuses to run without `--key` unless `--unsigned` is passed. Keep that.

## Blocking decisions

Neither is resolved, and this branch cannot merge until both are (`docs/SPEC.md` §9):

- **D1 — where is the repo hosted?** 864 MiB rules out GitHub Pages.
- **D2 — who holds the offline signing primary key, and where?** The build machine must
  only ever see a signing subkey.

## Traps this branch already hit

- `dist/` (864 MiB) was staged into git because the branch predated the ignore rule.
  `dist/` is in `.gitignore` on `main`; make sure the rebase keeps it.
- Reverting a branch's commit on `main` makes the original an ancestor, and the reopened PR
  then shows an empty diff. Rebuild the branch on `main` with a re-apply commit instead.
