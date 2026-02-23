#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing all claude-mods..."
echo

bash "$SCRIPT_DIR/spending-tracker/install.sh"
echo
bash "$SCRIPT_DIR/notify/install.sh"

echo

# --- Skills marketplace ---
echo "Installing skills marketplace..."
MARKETPLACE_NAME="claude-skills-custom"
MARKETPLACE_DIR="$HOME/.claude/plugins/marketplaces"
LINK_TARGET="$MARKETPLACE_DIR/$MARKETPLACE_NAME"

mkdir -p "$MARKETPLACE_DIR"

# Symlink claude-skills/ into the marketplaces directory
[ -L "$LINK_TARGET" ] && rm "$LINK_TARGET"
[ -d "$LINK_TARGET" ] && { echo "ERROR: $LINK_TARGET is a real directory, not a symlink. Remove it manually."; exit 1; }
ln -s "$SCRIPT_DIR/claude-skills" "$LINK_TARGET"
echo "  Symlinked $LINK_TARGET -> $SCRIPT_DIR/claude-skills"

# Register marketplace in known_marketplaces.json (idempotent)
KNOWN="$HOME/.claude/plugins/known_marketplaces.json"
python3 - "$KNOWN" "$MARKETPLACE_NAME" "$LINK_TARGET" <<'PYEOF'
import json, sys, os
path, name, install_loc = sys.argv[1], sys.argv[2], sys.argv[3]
data = {}
if os.path.isfile(path):
    with open(path) as f:
        data = json.load(f)
if name not in data:
    data[name] = {
        "source": {"source": "local"},
        "installLocation": install_loc
    }
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"  Registered '{name}' in {path}")
else:
    print(f"  '{name}' already registered in {path}")
PYEOF

echo
echo "All mods and skills installed."
