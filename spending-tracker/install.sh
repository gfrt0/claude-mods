#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"

# Copy scripts and make executable
cp "$SCRIPT_DIR/statusline.sh" "$CLAUDE_DIR/statusline.sh"
cp "$SCRIPT_DIR/session-cost-logger.sh" "$CLAUDE_DIR/session-cost-logger.sh"
chmod +x "$CLAUDE_DIR/statusline.sh" "$CLAUDE_DIR/session-cost-logger.sh"

# Merge into settings.json (create or update)
python3 -c "
import json, os

settings_path = os.path.expanduser('$SETTINGS')

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

settings['statusLine'] = {
    'type': 'command',
    'command': '~/.claude/statusline.sh'
}

hooks = settings.setdefault('hooks', {})
session_end = hooks.get('SessionEnd', [])

# Check if our hook is already registered
already = any(
    h.get('command') == '~/.claude/session-cost-logger.sh'
    for entry in session_end
    for h in entry.get('hooks', [])
)

if not already:
    session_end.append({
        'hooks': [{
            'type': 'command',
            'command': '~/.claude/session-cost-logger.sh'
        }]
    })
    hooks['SessionEnd'] = session_end

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
"

echo "Spending tracker installed."
echo "  - ~/.claude/statusline.sh"
echo "  - ~/.claude/session-cost-logger.sh"
echo "  - settings.json updated"
