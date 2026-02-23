#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing all claude-mods..."
echo

bash "$SCRIPT_DIR/spending-tracker/install.sh"
echo
bash "$SCRIPT_DIR/notify/install.sh"

echo

# --- Custom slash commands ---
echo "Installing custom slash commands..."
COMMANDS_DIR="$HOME/.claude/commands"
mkdir -p "$COMMANDS_DIR"

for md in "$SCRIPT_DIR/commands/"*.md; do
  [ -f "$md" ] || continue
  cp "$md" "$COMMANDS_DIR/"
  echo "  Installed $(basename "$md") -> $COMMANDS_DIR/"
done

# Clean up old plugins/marketplaces structure if present (no longer used)
if [ -d "$HOME/.claude/plugins" ]; then
  rm -rf "$HOME/.claude/plugins"
  echo "  Removed stale ~/.claude/plugins/ directory"
fi

echo
echo "All mods and skills installed."
