#!/usr/bin/env bash
set -e

# Define paths
CACHE_DIR="/root/.cache/wheels"
REQ_FILE="/root/requirements.txt"
VENV_ROOT="/root/.local/state/quickshell/.venv"
VENV_SKEL="/etc/skel/.local/state/quickshell/.venv"

# Function to setup venv
setup_venv() {
    local venv_path="$1"
    echo "Setting up venv at $venv_path"
    
    mkdir -p "$(dirname "$venv_path")"
    
    # Create venv if it doesn't exist
    if [ ! -d "$venv_path" ]; then
        uv venv "$venv_path" --python 3.12
    fi
    
    # Activate and install
    source "$venv_path/bin/activate"
    
    echo "Installing requirements from local cache..."
    # --no-index ensures we don't try to hit PyPI
    # --find-links points to our local wheel directory
    uv pip install --no-index --find-links "$CACHE_DIR" -r "$REQ_FILE"
    
    deactivate
}

# 1. Setup /root venv
if [ -d "$CACHE_DIR" ]; then
    setup_venv "$VENV_ROOT"
    
    # 2. Setup /etc/skel venv
    setup_venv "$VENV_SKEL"
    
    # Cleanup (Optional: uncomment to save space, but keeping cache might be useful)
    # rm -rf "$CACHE_DIR"
else
    echo "Wheel cache not found at $CACHE_DIR. Skipping offline install."
fi
