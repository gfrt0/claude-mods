#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"

# Copy script and make executable
cp "$SCRIPT_DIR/auto-catchup.sh" "$CLAUDE_DIR/auto-catchup.sh"
chmod +x "$CLAUDE_DIR/auto-catchup.sh"

# Merge SessionStart matcher:"startup" hook into settings.json
# (preserves any existing SessionStart entries with other matchers, e.g. compact|resume)
python3 -c "
import json, os

settings_path = os.path.expanduser('$SETTINGS')

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

hooks = settings.setdefault('hooks', {})
session_start = hooks.setdefault('SessionStart', [])

hook_command = os.path.expanduser('~/.claude/auto-catchup.sh')

# Dedup: normalise tilde and absolute path so re-installs don't duplicate.
def _norm(cmd):
    return os.path.expanduser(cmd or '').rstrip()

target = _norm(hook_command)

# Remove any pre-existing startup entry pointing at this script (tilde or absolute).
session_start = [
    entry for entry in session_start
    if not (
        entry.get('matcher') == 'startup'
        and any(_norm(h.get('command')) == target for h in entry.get('hooks', []))
    )
]

# Add the canonical absolute-path entry.
session_start.append({
    'matcher': 'startup',
    'hooks': [{
        'type': 'command',
        'command': hook_command,
        'timeout': 5000
    }]
})
hooks['SessionStart'] = session_start

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
"

echo "auto-catchup installed."
echo "  - ~/.claude/auto-catchup.sh"
echo "  - settings.json updated (SessionStart matcher:\"startup\" hook)"
