#!/bin/bash
# PreToolUse(Bash) — block HITL-tier Bash operations until user approval.
# Reads tool input JSON from stdin (Claude Code hook protocol).
# exit 0 = allow; exit 2 = block (printing reason to stderr).
#
# Bypass: prefix the command with `HITL_BYPASS=1` after the user has explicitly
# approved the operation in chat. Example:
#   HITL_BYPASS=1 git push origin main
#
# Heredoc handling: heredoc bodies are stripped before pattern matching to
# avoid false positives on commit messages that mention dangerous patterns.

set -e

COMMAND=$(jq -r '.tool_input.command // empty' 2>/dev/null || echo "")

if [ -z "$COMMAND" ]; then exit 0; fi

# --- Bypass flag (user-approved) ---
if echo "$COMMAND" | grep -qE '^[[:space:]]*HITL_BYPASS=(1|true)[[:space:]]'; then
  exit 0
fi

# --- Strip heredoc bodies before pattern matching ---
# Uses python3 (available on macOS by default) for portable regex handling.
STRIPPED=$(printf '%s' "$COMMAND" | python3 -c '
import sys, re
text = sys.stdin.read()
delim_re = re.compile(r"<<-?\s*[\"\x27]?([A-Za-z_][A-Za-z0-9_]*)[\"\x27]?")
out, in_heredoc, tag = [], False, None
for line in text.split("\n"):
    if in_heredoc:
        if line.strip() == tag:
            in_heredoc, tag = False, None
            out.append(line)
        # else: drop the heredoc body line
    else:
        out.append(line)
        m = delim_re.search(line)
        if m:
            tag = m.group(1)
            in_heredoc = True
print("\n".join(out))
' 2>/dev/null || printf '%s' "$COMMAND")

# --- HITL pattern checks (against stripped command) ---
BLOCKED_PATTERN=""
BLOCKED_REASON=""

if echo "$STRIPPED" | grep -qE '\bgit[[:space:]]+push\b'; then
  BLOCKED_PATTERN="git push"
  BLOCKED_REASON="Pushes to a remote — visible to others, hard to revert."
fi

if echo "$STRIPPED" | grep -qE '\bgit[[:space:]]+merge\b'; then
  BLOCKED_PATTERN="git merge"
  BLOCKED_REASON="Merges branches — affects history."
fi

if echo "$STRIPPED" | grep -qE '\bgit[[:space:]]+branch[[:space:]]+(-D\b|--delete[[:space:]]+--force\b|-d[[:space:]]+--force\b)'; then
  BLOCKED_PATTERN="git branch -D"
  BLOCKED_REASON="Force-deletes a branch — may lose unmerged commits."
fi

if echo "$STRIPPED" | grep -qE '\brm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f[a-zA-Z]*r[a-zA-Z]*)\b'; then
  BLOCKED_PATTERN="rm -rf"
  BLOCKED_REASON="Recursive force-delete — irreversible."
fi

if echo "$STRIPPED" | grep -qE '\bgit[[:space:]]+rm[[:space:]]+(-r\b|--recursive\b)'; then
  BLOCKED_PATTERN="git rm -r"
  BLOCKED_REASON="Recursive removal from index — large blast radius."
fi

if echo "$STRIPPED" | grep -qE '\bgit[[:space:]]+reset[[:space:]]+--hard\b'; then
  BLOCKED_PATTERN="git reset --hard"
  BLOCKED_REASON="Discards uncommitted work."
fi

if echo "$STRIPPED" | grep -qE '\b(brew|npm|pip|pip3)[[:space:]]+install\b'; then
  BLOCKED_PATTERN="<pkg-mgr> install"
  BLOCKED_REASON="Installs new dependency — supply-chain consideration."
fi

if [ -n "$BLOCKED_PATTERN" ]; then
  echo "🔴 HITL gate: this command requires explicit user approval." >&2
  echo "   Pattern matched: $BLOCKED_PATTERN" >&2
  echo "   Reason: $BLOCKED_REASON" >&2
  echo "" >&2
  echo "   To proceed after user approval, prefix with:" >&2
  echo "     HITL_BYPASS=1 <command>" >&2
  echo "" >&2
  echo "   See docs/harness/gate-matrix.md" >&2
  exit 2
fi

exit 0
