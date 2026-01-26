#!/bin/bash
# customize_airootfs.sh
# This script runs inside the chroot during the ISO build process.

set -e

echo "=== EndOS Customization: Quickshell Venv Setup ==="

VENV_DIR="/usr/share/quickshell/venv"
WHEELS_DIR="/var/cache/wheels"
# The requirements file is in the dots-hyprland repo in skel
REQ_FILE="/etc/skel/dots-hyprland/sdata/uv/requirements.txt"

if [ ! -d "$WHEELS_DIR" ]; then
    echo "WARNING: Wheels directory $WHEELS_DIR not found. Skipping venv setup."
    exit 0
fi

if [ ! -f "$REQ_FILE" ]; then
    echo "WARNING: Requirements file $REQ_FILE not found. Skipping venv setup."
    exit 0
fi

echo "Creating virtual environment at $VENV_DIR using Python 3.14..."
# Create parent directory
mkdir -p $(dirname "$VENV_DIR")

# Create venv with Python 3.14 and system site packages enabled
python3.14 -m venv --system-site-packages "$VENV_DIR"

echo "Installing wheels from $WHEELS_DIR..."
source "$VENV_DIR/bin/activate"

# Verify pip is working
pip --version

# Install dependencies using the cached wheels
# We use --no-index and --find-links to force using our local wheels
# We add --no-cache-dir to avoid populating /root/.cache inside the ISO
echo "Installing packages..."
pip install --no-cache-dir --no-index --find-links "$WHEELS_DIR" -r "$REQ_FILE"

echo "Verifying installation..."
pip list

echo "Deactivating venv..."
deactivate

# Optional: Clean up wheels to save ISO space?
# build.sh handles cleanup of the source, but the copies in airootfs might persist
# unless we delete them here.
echo "Cleaning up airootfs wheels..."
rm -rf "$WHEELS_DIR"

echo "=== System Configuration Setup ==="

# Configure user groups (from 2.setups.sh)
echo "Creating system groups..."
if [ -z "$(getent group i2c)" ]; then
    groupadd i2c
fi

# Configure kernel modules (from 2.setups.sh)
echo "Setting up kernel module loading..."
echo "i2c-dev" > /etc/modules-load.d/i2c-dev.conf

# Enable systemd services (from 2.setups.sh)
echo "Enabling systemd services..."
systemctl enable bluetooth

# Configure ydotool systemd user service link if needed
if [ ! -e "/usr/lib/systemd/user/ydotool.service" ] && [ -e "/usr/lib/systemd/system/ydotool.service" ]; then
    ln -s /usr/lib/systemd/system/ydotool.service /usr/lib/systemd/user/ydotool.service
fi

# Note: User-specific services (ydotool --user) and usermod operations 
# are handled in post-install-dots.sh since they require an actual user context

echo "=== Shrinking ISO Size ==="

# Remove documentation, man pages and info pages
echo "Removing documentation..."
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /usr/share/info/*
rm -rf /usr/share/gtk-doc/*

# Remove locale files (keep only English)
echo "Removing unnecessary locales..."
find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' -exec rm -rf {} + 2>/dev/null || true
find /usr/share/i18n/locales -mindepth 1 -maxdepth 1 ! -name 'en_*' ! -name 'POSIX' -exec rm -rf {} + 2>/dev/null || true

# Clean pacman cache
echo "Cleaning pacman cache..."
pacman -Sc --noconfirm
rm -rf /var/cache/pacman/pkg/*

# Clean build/development files not needed in live environment
echo "Removing development files..."
find /usr/lib -name '*.a' -delete 2>/dev/null || true
find /usr -name '__pycache__' -type d -exec rm -rf {} + 2>/dev/null || true
find /usr -name '*.pyc' -delete 2>/dev/null || true
find /usr -name '*.pyo' -delete 2>/dev/null || true

# Clean temporary files and logs
echo "Cleaning logs and temp files..."
rm -rf /var/log/*
rm -rf /var/tmp/*
rm -rf /tmp/*
rm -rf /var/log/journal/*
rm -rf /root/.cache/*
rm -rf /home/*/. cache/* 2>/dev/null || true

# Clean unnecessary systemd files
echo "Cleaning systemd boot entries..."
rm -rf /boot/loader/entries/*

echo "=== EndOS Customization Complete ==="
