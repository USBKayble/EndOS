#!/usr/bin/env bash
# Post-install script for dots-hyprland - runs automatically on first boot
# This script performs minimal first-boot setup since most configs are pre-baked

set -e

# Ensure this script only runs once
FLAG_FILE="${HOME}/.config/dots-hyprland-installed"
if [[ -f "$FLAG_FILE" ]]; then
    echo "[$0]: dots-hyprland already installed, skipping..."
    exit 0
fi

echo "=== EndOS First Boot Setup ==="

# Find the dots-hyprland repository
DOTS_DIR=""
for dir in "${HOME}/dots-hyprland" "/root/dots-hyprland" "/opt/dots-hyprland"; do
    if [[ -d "$dir" && -f "$dir/setup" ]]; then
        DOTS_DIR="$dir"
        break
    fi
done

if [[ -z "$DOTS_DIR" ]]; then
    echo "[$0]: ERROR: Could not find dots-hyprland repository"
    exit 1
fi

cd "$DOTS_DIR"
REPO_ROOT="$(pwd)"
export REPO_ROOT

# Source necessary library files
source ./sdata/lib/environment-variables.sh
source ./sdata/lib/functions.sh

# Set environment for automated installation
export ask=false
export SKIP_ALLGREETING=true
export SKIP_ALLDEPS=true  # Dependencies are pre-installed in ISO
export SKIP_BACKUP=true
export INSTALL_FIRSTRUN=true
export IGNORE_OUTDATE_CHECK=true

# Setup quickshell Python virtual environment
echo "[$0]: Setting up quickshell Python environment..."
VENV_DIR="${HOME}/.local/state/quickshell/.venv"
mkdir -p "$(dirname "$VENV_DIR")"
if [[ ! -d "$VENV_DIR" ]] && command -v python3 &>/dev/null; then
    python3 -m venv "$VENV_DIR" 2>/dev/null || true
    if [[ -f "$VENV_DIR/bin/activate" ]]; then
        source "$VENV_DIR/bin/activate"
        REQUIREMENTS="${DOTS_DIR}/sdata/uv/requirements.txt"
        if [[ -f "$REQUIREMENTS" ]]; then
            pip install --quiet --no-cache-dir -r "$REQUIREMENTS" 2>/dev/null || true
        fi
        deactivate
        echo "[$0]: Quickshell venv created at $VENV_DIR"
    fi
else
    echo "[$0]: Quickshell venv already exists or python3 not available"
fi

# Setup user groups (quick operation)
echo "[$0]: Setting up user groups..."
if [[ -z $(getent group i2c) ]]; then
    sudo groupadd i2c 2>/dev/null || true
fi
sudo usermod -aG video,i2c,input "$(whoami)" 2>/dev/null || true

# Enable i2c-dev module
echo "i2c-dev" | sudo tee /etc/modules-load.d/i2c-dev.conf >/dev/null 2>&1 || true

# Enable and start ydotool if available
if command -v ydotoold >/dev/null 2>&1; then
    systemctl --user enable ydotool --now 2>/dev/null || true
fi

# Enable bluetooth
sudo systemctl enable bluetooth --now 2>/dev/null || true

# Set GNOME/KDE defaults
gsettings set org.gnome.desktop.interface font-name 'Google Sans Flex Medium 11 @opsz=11,wght=500' 2>/dev/null || true
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
kwriteconfig6 --file kdeglobals --group KDE --key widgetStyle Darkly 2>/dev/null || true

# Create flag file to prevent running again
mkdir -p "$(dirname "$FLAG_FILE")"
touch "$FLAG_FILE"

echo "[$0]: First boot setup completed!"
echo ""
echo "Press Ctrl+Super+T to select a wallpaper"
echo "Press Super+/ for a list of keybinds"
