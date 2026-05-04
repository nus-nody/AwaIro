#!/bin/bash
# PreToolUse(Edit|Write) — block edits to sensitive files until user approval.
# Reads tool input JSON from stdin (Claude Code hook protocol).
# exit 0 = allow; exit 2 = block (printing reason to stderr).
#
# This complements hitl-bash-gate.sh by covering operations that don't go through
# Bash: Xcode project tinkering, Info.plist / entitlements changes, and
# Package.swift dependency edits.
#
# Bypass mechanism (one-shot marker file):
#
#   To allow ONE upcoming edit on a sensitive path after explicit user approval,
#   the orchestrator writes a regex pattern to .claude/hooks/.bypass-next-edit
#   BEFORE triggering the Edit/Write tool. This hook reads the pattern, deletes
#   the marker file (single-use), and if the target path matches the pattern,
#   allows the operation.
#
#   Example (orchestrator workflow):
#     # User approved editing Package.swift in chat
#     echo 'Package\.swift$' > .claude/hooks/.bypass-next-edit
#     # Now use the Edit tool on Package.swift — hook allows, marker consumed.
#
#   The marker file is consumed even if the pattern doesn't match the next edit,
#   to prevent stale bypasses from leaking. If you need to allow multiple edits,
#   write the marker before each one.

set -e

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || echo "")

if [ -z "$FILE" ]; then exit 0; fi

# --- Bypass marker (one-shot, consumed on read) ---
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
MARKER="$PROJECT_DIR/.claude/hooks/.bypass-next-edit"
if [ -f "$MARKER" ]; then
  BYPASS_PATTERN=$(cat "$MARKER" 2>/dev/null || echo "")
  rm -f "$MARKER"  # consume regardless of match
  if [ -n "$BYPASS_PATTERN" ] && echo "$FILE" | grep -qE "$BYPASS_PATTERN"; then
    echo "✅ HITL bypass consumed: $FILE matched '$BYPASS_PATTERN'" >&2
    exit 0
  fi
fi

# --- Sensitive path patterns ---
BLOCKED_PATTERN=""
BLOCKED_REASON=""

case "$FILE" in
  *.xcodeproj/*|*.xcworkspace/*)
    BLOCKED_PATTERN="Xcode project/workspace internals"
    BLOCKED_REASON="Direct edits can corrupt the project file. Use Xcode UI when possible."
    ;;
  */Info.plist|Info.plist)
    BLOCKED_PATTERN="Info.plist"
    BLOCKED_REASON="Affects app capabilities, permissions, and entitlements."
    ;;
  *.entitlements)
    BLOCKED_PATTERN="entitlements"
    BLOCKED_REASON="Changes app sandbox / capabilities — security boundary."
    ;;
  */Package.swift|Package.swift)
    BLOCKED_PATTERN="Package.swift"
    BLOCKED_REASON="Dependency changes need HITL (supply-chain). Target/source edits also affect build."
    ;;
  */Package.resolved|Package.resolved)
    BLOCKED_PATTERN="Package.resolved"
    BLOCKED_REASON="Pinned dependency versions — never edit by hand."
    ;;
esac

if [ -n "$BLOCKED_PATTERN" ]; then
  echo "🔴 HITL gate: edit to sensitive file requires explicit user approval." >&2
  echo "   File: $FILE" >&2
  echo "   Pattern: $BLOCKED_PATTERN" >&2
  echo "   Reason: $BLOCKED_REASON" >&2
  echo "" >&2
  echo "   To proceed after user approval, write a pattern to the marker file:" >&2
  echo "     echo '<regex>' > .claude/hooks/.bypass-next-edit" >&2
  echo "     # then use Edit/Write on the file (single-use)" >&2
  echo "" >&2
  echo "   See docs/harness/gate-matrix.md" >&2
  exit 2
fi

exit 0
