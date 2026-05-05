#!/bin/bash
# AwaIro project status line.
# Shows: 🌊 <branch> · <model> [· <hint>]
#
# Hint logic: if working on a "conversion/phase-*" branch with non-Opus model,
# remind that plan/reviewer evaluation turns prefer Opus (per CLAUDE.md).
# Reads Claude Code session JSON from stdin.

set -eu

input=$(cat)

# --- Model ---
model_id=$(printf '%s' "$input" | jq -r '.model.id // "?"' 2>/dev/null || echo "?")
case "$model_id" in
  *opus-4-7*)   m="Opus 4.7" ;;
  *opus-4-6*)   m="Opus 4.6 (fast)" ;;
  *sonnet-4-6*) m="Sonnet 4.6" ;;
  *haiku-4-5*)  m="Haiku 4.5" ;;
  *)            m="$model_id" ;;
esac

# --- Branch ---
project_dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .workspace.project_dir // "."' 2>/dev/null || echo ".")
b=$(git -C "$project_dir" branch --show-current 2>/dev/null || echo "?")

# --- Phase hint ---
hint=""
case "$b" in
  conversion/phase-*|*-plan*|*-spec*|main|master)
    case "$model_id" in
      *opus*) ;;
      *)
        hint=" · plan/review なら /model opus"
        ;;
    esac
    ;;
esac

printf "🌊 %s · %s%s\n" "$b" "$m" "$hint"
