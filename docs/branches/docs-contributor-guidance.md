# Branch: `docs/contributor-guidance`

**State:** open, not yet merged · **Owner:** @edbron

## Charter

A single place to point a contributor — human or agent — at, instead of
letting the branching rules, the commit conventions and the no-AI-co-author
policy live only in whoever remembers them. `CONTRIBUTING.md` becomes the
canonical guide; `CLAUDE.md` and `AGENTS.md` become thin pointers at it
rather than a third copy; and the trailer policy is enforced by a hook
instead of relying on memory.

## Scope

| Path | Role |
|---|---|
| `CONTRIBUTING.md` | canonical contributor guide: branching, testing, commits |
| `CLAUDE.md` | agent-specific pointer — the parts an agent gets wrong by default |
| `AGENTS.md` | tool-agnostic pointer at `CLAUDE.md` |
| `.githooks/commit-msg` | strips AI attribution trailers from a commit message |
| `tests/commit-hygiene.bats` | regression guard for the hook and the docs |

## The rule that defines this branch

**Commits are credited to the person who made them.** The hook exists so
nobody has to remember to strip `Co-Authored-By: Claude …` and
`Claude-Session: …` by hand, but it is a convenience, not a gate — nothing
in `build.sh` or `tests/` depends on it being installed, and it only ever
matches a trailer at column 0. An indented line inside a code block or a
quoted example is body prose, not a trailer, and survives on purpose.

## Traps this branch already hit

- **An anchored-but-too-loose trailer pattern deletes body prose.** The
  hook's original regexes allowed leading whitespace, which reaches into
  quoted examples and pasted diff context as well as real trailers. Match
  only column 0.
- **A contributor named Claude is not a false positive the hook can special
  case.** `Co-Authored-By: Claude Mensah <...>` is indistinguishable from
  the AI trailer by text alone; `CONTRIBUTING.md` says so rather than
  claiming the hook is smarter than it is.

## Follow-up work

- No CI runs `bats tests/` yet, so a missed hook install is caught only by a
  human reviewer noticing a trailer. Wiring that up belongs to `build/`, not
  here.
