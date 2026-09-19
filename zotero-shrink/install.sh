#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR"

for s in zotero-pdf-shrink.sh zotero-pdf-watcher.sh; do
  cp "$SCRIPT_DIR/$s" "$CLAUDE_DIR/$s"
  chmod +x "$CLAUDE_DIR/$s"
done

echo "zotero-shrink installed: ~/.claude/zotero-pdf-shrink.sh, ~/.claude/zotero-pdf-watcher.sh"

if ! command -v gs >/dev/null 2>&1; then
  echo "  WARNING: ghostscript (gs) not found -- both scripts refuse to run without it."
  echo "           sudo apt install ghostscript"
fi

echo "One-off batch pass (start with --dry-run):"
echo "  ~/.claude/zotero-pdf-shrink.sh --dry-run --verbose"
echo "Background watcher (polls every 60s; inotify does not work on /mnt/c):"
echo "  nohup ~/.claude/zotero-pdf-watcher.sh >/dev/null 2>&1 &"
