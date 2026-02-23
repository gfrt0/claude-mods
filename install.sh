#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing all claude-mods..."
echo

bash "$SCRIPT_DIR/spending-tracker/install.sh"
echo
bash "$SCRIPT_DIR/notify/install.sh"

echo
echo "All mods installed."
