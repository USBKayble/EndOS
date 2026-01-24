#!/bin/bash
# customize_airootfs.sh
# This script runs inside the chroot during the ISO build process.

set -e

echo "=== EndOS Customization: Quickshell Venv Setup ==="

VENV_DIR="/usr/share/quickshell/venv"
WHEELS_DIR="/var/cache/wheels"
# The requirements file is copied by build.sh to this location in the ISO
REQ_FILE="/home/liveuser/dots-hyprland/sdata/uv/requirements.txt"

if [ ! -d "$WHEELS_DIR" ]; then
    echo "WARNING: Wheels directory $WHEELS_DIR not found. Skipping venv setup."
    exit 0
fi

echo "Creating virtual environment at $VENV_DIR..."
# Create parent directory
mkdir -p $(dirname "$VENV_DIR")

# Create venv with system site packages enabled
python3 -m venv --system-site-packages "$VENV_DIR"

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

echo "=== Shrinking ISO Size ==="
# Remove documentation man pages and info pages
echo "Removing documentation..."
rm -rf /usr/share/doc/*
rm -rf /usr/share/man/*
rm -rf /usr/share/info/*

# Clean pacman cache
echo "Cleaning pacman cache..."
pacman -Sc --noconfirm
rm -rf /var/cache/pacman/pkg/*

# Clean temporary files and logs
echo "Cleaning logs and temp files..."
rm -rf /var/log/*
rm -rf /var/tmp/*
# Clean journal
rm -rf /var/log/journal/*

echo "=== EndOS Customization Complete ==="
