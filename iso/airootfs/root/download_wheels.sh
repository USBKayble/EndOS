#!/bin/bash
set -e

# download_wheels.sh
# Runs in WSL to download/build Python wheels for the ISO

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REQ_FILE="$SCRIPT_DIR/requirements.txt"
DEST_DIR="$SCRIPT_DIR/.cache/wheels"

echo "Checking build dependencies..."
# Check for dbus and glib2 headers which are often needed for dbus-python
MISSING_DEPS=()
if ! pkg-config --exists dbus-1; then
    MISSING_DEPS+=("dbus")
fi
if ! pkg-config --exists glib-2.0; then
    MISSING_DEPS+=("glib2")
fi
if ! command -v pip &> /dev/null; then
    MISSING_DEPS+=("python-pip")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo "WARNING: Missing build dependencies/tools: ${MISSING_DEPS[*]}"
    echo "Attempting to install them with pacman..."
    sudo pacman -S --needed --noconfirm base-devel dbus glib2 python-pip
fi

echo "Creating wheel directory at $DEST_DIR..."
mkdir -p "$DEST_DIR"

echo "Building/Downloading wheels..."
# Use pip wheel to build from source if necessary (for dbus-python)
# We do NOT force a platform tag here, trusting the WSL env matches the ISO target (Arch)
# or at least produces compatible linux_x86_64 wheels.
pip wheel --wheel-dir "$DEST_DIR" -r "$REQ_FILE"

echo "Wheel processing complete."
ls -lh "$DEST_DIR"
