#!/bin/bash
# auto-catchup hook (SessionStart, matcher: startup).
#
# Reads hook JSON from stdin, finds the project's git state, and emits a
# system-reminder asking Claude to run /catchup before responding to the
# user's first message. Includes a small git breadcrumb so context is
# visible even if /catchup is suppressed or fails.
#
# Silent (exit 0) on:
#  - non-git directories
#  - missing cwd
#  - any error reading git state

set -e

# Debug log (for verifying the hook actually fires). Kept lightweight — one line per invocation.
LOG_FILE="$HOME/.claude/auto-catchup.log"
INPUT=$(cat)
echo "[$(date '+%Y-%m-%d %H:%M:%S')] fired, stdin=${#INPUT}b" >> "$LOG_FILE" 2>/dev/null || true

# Parse hook JSON from captured stdin
CWD=$(echo "$INPUT" | python3 -c "import sys, json; print(json.load(sys.stdin).get('cwd', ''))" 2>/dev/null || echo "")

[ -z "$CWD" ] && exit 0
[ ! -d "$CWD" ] && exit 0

# Bail silently if not in a git repo
if ! git -C "$CWD" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    exit 0
fi

REPO_NAME=$(basename "$(git -C "$CWD" rev-parse --show-toplevel 2>/dev/null)")
BRANCH=$(git -C "$CWD" branch --show-current 2>/dev/null || echo "?")
LAST_COMMIT=$(git -C "$CWD" log -1 --format='%h %s' 2>/dev/null || echo "?")
DIRTY_COUNT=$(git -C "$CWD" status --short 2>/dev/null | wc -l | tr -d ' ')

# Check for session_logs/ in this repo (signals we're in a project that uses /session-log)
HAS_SESSION_LOGS=""
if [ -d "$CWD/session_logs" ] && [ -n "$(ls -A "$CWD/session_logs" 2>/dev/null)" ]; then
    HAS_SESSION_LOGS="yes"
fi

# Heuristic: do the 5 most recent session logs mention pending Myriad jobs or
# pending postprocess? Scan each log for a non-empty "## Myriad jobs" or
# "## Pending postprocess" section (content = list items starting with "- ").
# If yes, /catchup should hit `ssh myriad qstat`. If no, /catchup should skip
# the SSH step — saves 2-5s on every cold start and avoids auth failures when
# the user has no cluster state to check.
HAS_PENDING_MYRIAD=""
if [ -n "$HAS_SESSION_LOGS" ]; then
    for log in $(ls -t "$CWD/session_logs/"*.md 2>/dev/null | head -5); do
        if awk '
            /^## Myriad jobs/ || /^## Pending postprocess/ { in_section=1; next }
            /^## / { in_section=0 }
            in_section && /^- / { print "HAS"; exit }
        ' "$log" 2>/dev/null | grep -q HAS; then
            HAS_PENDING_MYRIAD="yes"
            break
        fi
    done
fi

cat <<EOF
## Session start — auto-catchup

**Repo:** \`$REPO_NAME\`
**Branch:** \`$BRANCH\`
**Last commit:** $LAST_COMMIT
EOF

if [ "$DIRTY_COUNT" -gt 0 ]; then
    echo "**Uncommitted:** $DIRTY_COUNT files modified/untracked"
fi

if [ -n "$HAS_SESSION_LOGS" ]; then
    echo "**Session logs:** present in \`session_logs/\`"
fi

if [ -n "$HAS_PENDING_MYRIAD" ]; then
    echo "**Myriad state:** pending jobs detected in recent session logs — full cluster status check requested"
else
    echo "**Myriad state:** no pending jobs in recent session logs — cluster check will be skipped"
fi

echo
echo "---"
echo

if [ -n "$HAS_PENDING_MYRIAD" ]; then
    cat <<'EOF'
**Startup task:** Before responding to the user's first message in this session, run `/catchup` to give them a briefing on recent repo activity (commits, issues/PRs, session logs, Myriad job outcomes). Recent session logs indicate pending Myriad jobs — include the full `ssh myriad` cluster status check.

**If `ssh myriad` fails** (stale socket, auth error, "Too many auth failures", connection timeout): stop the catchup, run `/setup-myriad-ssh` to repair the connection, then retry the Myriad portion of the catchup. If `/setup-myriad-ssh` itself fails, report the error to the user and skip the Myriad check for this catchup.

Respond to the user's message afterwards. If the user's first message says "skip catchup" or "no catchup", honor that and proceed directly.
EOF
else
    cat <<'EOF'
**Startup task:** Before responding to the user's first message in this session, run `/catchup` to give them a briefing on recent repo activity (commits, issues/PRs, session logs). **Skip the `ssh myriad` cluster status check** this time — no pending Myriad jobs were detected in the 5 most recent session logs, so there's nothing on the cluster to check. Do not run `ssh myriad` at all. All other catchup steps (git log, gh issues/PRs, session logs, MEMORY.md) should proceed normally.

Respond to the user's message afterwards. If the user's first message says "skip catchup" or "no catchup", honor that and proceed directly.
EOF
fi
