#!/bin/bash
# Stop hook — show uncommitted changes for context preservation
set -e

if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  echo ""
  echo "📝 Uncommitted changes:"
  git status --short
fi

exit 0
