#!/bin/bash
# Run the installer in DRY RUN mode locally

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PYTHONPATH="$SCRIPT_DIR:$PYTHONPATH"

# Check for PySide6
if ! python3 -c "import PySide6" &>/dev/null; then
    echo "ERROR: pyside6 is not installed."
    echo "Please install it with: sudo pacman -S pyside6"
    exit 1
fi

echo "Starting Installer in Dry-Run Mode..."
# Mask KDE session to avoid forced Breeze styling
unset KDE_FULL_SESSION
unset XDG_CURRENT_DESKTOP
unset QT_QPA_PLATFORMTHEME
unset QT_STYLE_OVERRIDE
export QT_QUICK_CONTROLS_STYLE=Basic
python3 "$SCRIPT_DIR/main.py" --dry-run -style Basic
