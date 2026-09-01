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

# Lower-case and indented spellings still have to be caught -- a trailer that
# survives because of its capitalisation is the whole failure mode.
@test "the hook is case-insensitive about the trailer key" {
  msg="$BATS_TEST_TMPDIR/msg"
  printf '%s\n' \
    'docs: tweak' \
    '' \
    'co-authored-by: claude opus 5 <noreply@anthropic.com>' > "$msg"

  "$HOOK" "$msg"

  ! grep -qi 'claude' "$msg"
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
