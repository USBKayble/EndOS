#!/usr/bin/env bash
# Post-install script for dots-hyprland - runs automatically on first boot
# This script performs a fully automated installation of dots-hyprland

set -e

# Ensure this script only runs once
FLAG_FILE="/home/liveuser/.config/dots-hyprland-installed"
if [[ -f "$FLAG_FILE" ]]; then
    echo "[$0]: dots-hyprland already installed, skipping..."
    exit 0
fi

# Find the dots-hyprland repository
DOTS_DIR=""
for dir in "/home/liveuser/dots-hyprland" "$HOME/dots-hyprland" "/root/dots-hyprland" "/opt/dots-hyprland"; do
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

echo "=== Starting automated dots-hyprland installation ==="

source ./sdata/lib/environment-variables.sh
source ./sdata/lib/functions.sh
source ./sdata/lib/dist-determine.sh
source ./sdata/lib/package-installers.sh

export ask=false
export SKIP_ALLGREETING=true
export SKIP_ALLDEPS=false
export SKIP_ALLSETUPS=false
export SKIP_ALLFILES=false
export SKIP_BACKUP=true
export INSTALL_FIRSTRUN=true
export IGNORE_OUTDATE_CHECK=true
export DEBIAN_FRONTEND=noninteractive

prevent_sudo_or_root

sudo_init_keepalive
trap sudo_stop_keepalive EXIT INT TERM

echo "[$0]: Step 1 - Installing dependencies"
for function in "${print_os_group_id_functions[@]}"; do
    $function
done
source ./sdata/subcmd-install/1.deps-router.sh

echo "[$0]: Step 2 - Setting up permissions and services"
source ./sdata/subcmd-install/2.setups.sh

echo "[$0]: Step 3 - Copying config files"
source ./sdata/subcmd-install/3.files.sh

# Create flag file to prevent running again
mkdir -p "$(dirname "$FLAG_FILE")"
touch "$FLAG_FILE"

echo "[$0]: Automated installation completed successfully!"
