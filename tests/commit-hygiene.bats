#!/usr/bin/env bats
ROOT="$BATS_TEST_DIRNAME/.."
HOOK="$ROOT/.githooks/commit-msg"

@test "the commit-msg hook is tracked and executable" {
  [ -x "$HOOK" ]
  git -C "$ROOT" ls-files --error-unmatch .githooks/commit-msg
}

# Claude Code appends both trailers by default. Commits here are credited to
# the person who made them, so the hook removes them rather than asking
# everyone to remember.
@test "the hook strips the Claude co-author and session trailers" {
  msg="$BATS_TEST_TMPDIR/msg"
  printf '%s\n' \
    'shell: fix the thing' \
    '' \
    'A real body paragraph that must survive.' \
    '' \
    'Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>' \
    'Claude-Session: https://claude.ai/code/session_abc123' > "$msg"

  "$HOOK" "$msg"

  grep -q 'shell: fix the thing' "$msg"
  grep -q 'A real body paragraph that must survive.' "$msg"
  ! grep -qi 'claude' "$msg"
}

# Lower-case spellings still have to be caught -- a trailer that survives
# because of its capitalisation is the whole failure mode.
@test "the hook is case-insensitive about the trailer key" {
  msg="$BATS_TEST_TMPDIR/msg"
  printf '%s\n' \
    'docs: tweak' \
    '' \
    'co-authored-by: claude opus 5 <noreply@anthropic.com>' > "$msg"

  "$HOOK" "$msg"

  ! grep -qi 'claude' "$msg"
}

# An indented line only *looks* like a trailer: inside a code block or a
# quoted example it is body prose the author wrote on purpose, and
# `git interpret-trailers --parse` agrees it isn't a trailer. The hook only
# matches column 0, so it must survive -- while a real trailer in the same
# message still gets stripped.
@test "an indented trailer inside quoted body text survives" {
  msg="$BATS_TEST_TMPDIR/msg"
  printf '%s\n' \
    'docs: show what the hook strips' \
    '' \
    'Example of what the hook removes:' \
    '' \
    '    Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' \
    '' \
    'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' > "$msg"

  "$HOOK" "$msg"

  grep -q '^    Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' "$msg"
  ! grep -q '^Co-Authored-By: Claude' "$msg"
}

# The hook must not become a blunt instrument against human collaborators.
@test "the hook keeps a genuine human co-author" {
  msg="$BATS_TEST_TMPDIR/msg"
  printf '%s\n' \
    'packages: add a package' \
    '' \
    'Co-Authored-By: DevInBlack001 <abdulbnarmi@gmail.com>' > "$msg"

  "$HOOK" "$msg"

  grep -q 'Co-Authored-By: DevInBlack001' "$msg"
}

@test "the hook leaves no trailing blank lines behind" {
  msg="$BATS_TEST_TMPDIR/msg"
  printf '%s\n' \
    'docs: tidy' \
    '' \
    'Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>' > "$msg"

  "$HOOK" "$msg"

  [ "$(tail -n1 "$msg")" = 'docs: tidy' ]
}

@test "a message with no trailers is passed through unchanged" {
  msg="$BATS_TEST_TMPDIR/msg"
  printf '%s\n' 'theme: adjust the palette' '' 'Body text.' > "$msg"
  before=$(cat "$msg")
  "$HOOK" "$msg"
  [ "$(cat "$msg")" = "$before" ]
}

@test "CONTRIBUTING.md is the canonical guide and covers the four areas" {
  doc="$ROOT/CONTRIBUTING.md"
  [ -f "$doc" ]
  grep -q '^## Branching'            "$doc"
  grep -q '^## Before you start'     "$doc"
  grep -q '^## Testing'              "$doc"
  grep -q '^## Commits'              "$doc"
  grep -q '^### No AI co-authorship' "$doc"
}

# The test command was practised but written down nowhere before this.
@test "CONTRIBUTING.md documents the real test and build commands" {
  grep -q 'bats tests/'  "$ROOT/CONTRIBUTING.md"
  grep -q './build.sh'   "$ROOT/CONTRIBUTING.md"
  grep -q './test-vm.sh' "$ROOT/CONTRIBUTING.md"
  [ -x "$ROOT/build.sh" ]
  [ -x "$ROOT/test-vm.sh" ]
}

@test "CONTRIBUTING.md documents installing the hook" {
  grep -q 'core.hooksPath .githooks' "$ROOT/CONTRIBUTING.md"
}

# One source of truth: the README must point at CONTRIBUTING.md rather than
# keeping its own copy of the branch table that can drift out of step.
@test "README delegates to CONTRIBUTING.md and keeps no rival copy" {
  grep -q 'CONTRIBUTING.md' "$ROOT/README.md"
  ! grep -q '^| `installer/` |' "$ROOT/README.md"
}

# The agent files are pointers, not a third copy of the rules. If one grows
# past ~80 lines it has started duplicating CONTRIBUTING.md (CLAUDE.md sits
# at 57 as written, so there is room to edit without tripping this).
@test "the agent guidance files defer to CONTRIBUTING.md" {
  for f in CLAUDE.md AGENTS.md; do
    [ -f "$ROOT/$f" ]
    grep -q 'CONTRIBUTING.md' "$ROOT/$f"
    [ "$(wc -l < "$ROOT/$f")" -lt 80 ]
  done
}

# The one rule an agent gets wrong by default has to be stated where the agent
# actually reads, not only behind a link.
@test "CLAUDE.md states the no-AI-co-author rule in full" {
  grep -q 'Co-Authored-By: Claude' "$ROOT/CLAUDE.md"
  grep -q 'Claude-Session'         "$ROOT/CLAUDE.md"
  grep -q 'bats tests/'            "$ROOT/CLAUDE.md"
}

@test "AGENTS.md points at CLAUDE.md rather than restating it" {
  grep -q 'CLAUDE.md' "$ROOT/AGENTS.md"
}
