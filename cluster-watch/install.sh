#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"

mkdir -p "$CLAUDE_DIR"
cp "$SCRIPT_DIR/watch_job.sh" "$CLAUDE_DIR/watch_job.sh"
chmod +x "$CLAUDE_DIR/watch_job.sh"

echo "cluster-watch installed: ~/.claude/watch_job.sh"
echo "Set per-project defaults in the environment if you like:"
echo "  CLUSTER_WATCH_HOST, CLUSTER_WATCH_LOGS, CLUSTER_WATCH_RESULTS, CLUSTER_WATCH_LOG_GLOB"
