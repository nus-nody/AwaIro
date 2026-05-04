#!/bin/bash
# PreToolUse(Edit|Write) — block edits to sensitive files until user approval.
# Reads tool input JSON from stdin (Claude Code hook protocol).
# exit 0 = allow; exit 2 = block (printing reason to stderr).
#
# This complements hitl-bash-gate.sh by covering operations that don't go through
# Bash: Xcode project tinkering, Info.plist / entitlements changes, and
# Package.swift dependency edits.
#
# Bypass is not implemented here yet — sensitive file edits should always be
# explicitly discussed. If the user has approved, just retry: this hook fires
# only on Edit/Write, and the user is in the loop reviewing the diff anyway.
# (Future: add HITL_APPROVED_PATHS=... env support if needed.)

set -e

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || echo "")

if [ -z "$FILE" ]; then exit 0; fi

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
    # Package.swift exists for every SPM package. Editing target list is fine,
    # but adding/removing dependencies needs HITL. We can't reliably distinguish
    # without diffing, so we err on the side of blocking and let user re-confirm.
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
  echo "   See docs/harness/gate-matrix.md" >&2
  exit 2
fi

exit 0
