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
# Note: System venv is pre-built at /usr/share/quickshell/venv
# This creates a user-specific venv only if needed for customization
echo "[$0]: Verifying quickshell Python environment..."

# Check if system venv exists
SYSTEM_VENV="/usr/share/quickshell/venv"
USER_VENV="${HOME}/.local/state/quickshell/.venv"

if [ -d "$SYSTEM_VENV" ] && [ -f "$SYSTEM_VENV/bin/activate" ]; then
    echo "[$0]: Using pre-built system venv at $SYSTEM_VENV"
    # The env.conf should already point to the system venv for live ISO
    # Users who install to disk may want to create their own venv later
else
    echo "[$0]: System venv not found, creating user venv at $USER_VENV..."
    mkdir -p "$(dirname "$USER_VENV")"
    if command -v python3.14 &>/dev/null; then
        python3.14 -m venv --system-site-packages "$USER_VENV" 2>/dev/null || true
        if [ -f "$USER_VENV/bin/activate" ]; then
            source "$USER_VENV/bin/activate"
            REQUIREMENTS="${DOTS_DIR}/sdata/uv/requirements.txt"
            if [ -f "$REQUIREMENTS" ]; then
                # Use cached wheels if available
                WHEELS_CACHE="/var/cache/wheels"
                if [ -d "$WHEELS_CACHE" ]; then
                    pip install --quiet --no-cache-dir --no-index --find-links "$WHEELS_CACHE" -r "$REQUIREMENTS" 2>/dev/null || \
                    pip install --quiet --no-cache-dir -r "$REQUIREMENTS" 2>/dev/null || true
                else
                    pip install --quiet --no-cache-dir -r "$REQUIREMENTS" 2>/dev/null || true
                fi
            fi
            deactivate
            echo "[$0]: User quickshell venv created at $USER_VENV"
            
            # Update env.conf to point to user venv
            ENV_CONF="${HOME}/.config/hypr/hyprland/env.conf"
            if [ -f "$ENV_CONF" ]; then
                sed -i "s|env = ILLOGICAL_IMPULSE_VIRTUAL_ENV,.*|env = ILLOGICAL_IMPULSE_VIRTUAL_ENV, ${USER_VENV}|g" "$ENV_CONF"
            fi
        fi
    else
        echo "[$0]: WARNING: python3.14 not available, quickshell may not work properly"
    fi
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
