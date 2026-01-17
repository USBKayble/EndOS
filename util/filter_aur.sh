#!/bin/bash
# util/filter_aur.sh

# Reads package names from stdin.
# Outputs package names that are NOT found in the configured pacman repositories.
# These are assumed to be AUR candidates.
#
# Usage: cat packages.txt | ./util/filter_aur.sh > aur_list.txt

if ! command -v pacman &> /dev/null; then
    echo "Error: pacman not found." >&2
    exit 1
fi

# Ensure we have fresh DBs for accurate checking (Fixes false positives like steam/lib32-nvidia-utils)
# We check for core.db or just force a sync if missing
if [ ! -f /var/lib/pacman/sync/core.db ] && [ ! -f /var/lib/pacman/sync/multilib.db ]; then
    echo "Syncing pacman databases..." >&2
    pacman -Sy >&2
fi

while read -r pkg; do
    # Skip empty lines and comments
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    
    # Check if package exists in sync db
    if ! pacman -Si "$pkg" &> /dev/null; then
        echo "$pkg"
    fi
done
