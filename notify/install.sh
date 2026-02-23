#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CLAUDE_DIR="$HOME/.claude"
SETTINGS="$CLAUDE_DIR/settings.json"

mkdir -p "$CLAUDE_DIR"

# Copy scripts and make executable
cp "$SCRIPT_DIR/cc-notify" "$CLAUDE_DIR/cc-notify"
cp "$SCRIPT_DIR/cc-notify-hook" "$CLAUDE_DIR/cc-notify-hook"
chmod +x "$CLAUDE_DIR/cc-notify" "$CLAUDE_DIR/cc-notify-hook"

# Merge hooks into settings.json (create or update)
python3 -c "
import json, os

settings_path = os.path.expanduser('$SETTINGS')

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

hooks = settings.setdefault('hooks', {})

hook_command = '~/.claude/cc-notify-hook'

for event in ('Notification', 'Stop', 'SubagentStop'):
    entries = hooks.get(event, [])

    already = any(
        h.get('command') == hook_command
        for entry in entries
        for h in entry.get('hooks', [])
    )

    if not already:
        entries.append({
            'hooks': [{
                'type': 'command',
                'command': hook_command
            }]
        })
        hooks[event] = entries

with open(settings_path, 'w') as f:
    json.dump(settings, f, indent=2)
"

echo "Toast notifications installed."
echo "  - ~/.claude/cc-notify"
echo "  - ~/.claude/cc-notify-hook"
echo "  - settings.json updated (Notification, Stop, SubagentStop hooks)"
