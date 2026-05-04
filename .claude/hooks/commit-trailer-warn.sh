#!/bin/bash
# PreToolUse(Bash) — warn (not block) when `git commit` lacks the project's
# Co-Authored-By trailer. Phase 0 had 1 trailer-omission incident with
# `git commit -F file.txt` where the message file forgot the trailer; this
# hook surfaces such omissions to stderr at commit time so they're caught
# before the commit lands.
#
# Detection:
#   - Inline -m message: greps the command for the trailer string
#   - -F message file: reads the file and greps
#   - Other forms (no -m, no -F: opens editor): no check (trailer typed by hand)
#
# This hook NEVER blocks — exit 0 always. Stderr output appears in the
# orchestrator's tool output and prompts a fix-up commit if needed.

set -e

COMMAND=$(jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then exit 0; fi

# Only act on `git commit` invocations
if ! echo "$COMMAND" | grep -qE '\bgit[[:space:]]+commit\b'; then
  exit 0
fi

# Skip merge / fixup / amend (different policy)
if echo "$COMMAND" | grep -qE '(--amend|--fixup|--squash)'; then
  exit 0
fi

REQUIRED_TRAILER="Co-Authored-By: Claude Opus 4.7"

MESSAGE_BODY=""

# Case 1: -F <file>
if echo "$COMMAND" | grep -qE '\-F[[:space:]]+'; then
  MSG_FILE=$(echo "$COMMAND" | sed -E 's/.*-F[[:space:]]+([^[:space:]]+).*/\1/')
  if [ -f "$MSG_FILE" ]; then
    MESSAGE_BODY=$(cat "$MSG_FILE" 2>/dev/null || echo "")
  fi

# Case 2: -m "<message>" (could include heredoc body)
elif echo "$COMMAND" | grep -qE '\-m[[:space:]]'; then
  MESSAGE_BODY="$COMMAND"  # we'll grep the whole command for the trailer
fi

if [ -z "$MESSAGE_BODY" ]; then
  exit 0
fi

if ! echo "$MESSAGE_BODY" | grep -qF "$REQUIRED_TRAILER"; then
  echo "" >&2
  echo "⚠️  Conventional Commit trailer missing." >&2
  echo "   Expected: $REQUIRED_TRAILER (1M context) <noreply@anthropic.com>" >&2
  echo "   See CLAUDE.md > Commit conventions" >&2
  echo "" >&2
  echo "   Commit will proceed; consider amending with the trailer." >&2
  echo "" >&2
fi

exit 0
