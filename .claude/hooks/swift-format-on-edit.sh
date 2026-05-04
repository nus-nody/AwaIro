#!/bin/bash
# PostToolUse(Edit|Write) — HOOTL: silently format Swift files
# Reads tool input JSON from stdin, extracts file path, runs swift-format if available.

set -e

FILE=$(jq -r '.tool_input.file_path // .tool_input.path // empty' 2>/dev/null || echo "")

if [ -z "$FILE" ]; then exit 0; fi
if [[ "$FILE" != *.swift ]]; then exit 0; fi
if [ ! -f "$FILE" ]; then exit 0; fi
if ! command -v swift-format > /dev/null 2>&1; then exit 0; fi

swift-format --in-place "$FILE" 2>/dev/null || true
exit 0
