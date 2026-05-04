#!/bin/bash
# PreToolUse(Bash) — warn on HITL-tier operations
# Reads tool input JSON from stdin, checks command for dangerous patterns.
# exit 2 blocks the operation; exit 0 allows it.

set -e

COMMAND=$(jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then exit 0; fi

# Patterns that require explicit user approval per docs/harness/gate-matrix.md
if echo "$COMMAND" | grep -qE '(git push|git merge|rm -rf )'; then
  echo "🔴 HITL gate: this command requires explicit user approval." >&2
  echo "   Pattern matched: git push | git merge | rm -rf" >&2
  echo "   See docs/harness/gate-matrix.md" >&2
  exit 2
fi

exit 0
