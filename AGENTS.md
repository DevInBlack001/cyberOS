# AGENTS.md

See [CLAUDE.md](CLAUDE.md) for agent guidance, and
[CONTRIBUTING.md](CONTRIBUTING.md) for the canonical contributor guide. Both
apply here regardless of which tool you are.

The rule most often broken: **do not add `Co-Authored-By: Claude …` or
`Claude-Session: …` trailers to commits.** Run `git config core.hooksPath
.githooks` once and the hook strips them for you.
