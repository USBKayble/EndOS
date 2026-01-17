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

while read -r pkg; do
    # Skip empty lines and comments
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue

    # Hardcoded safeguards for known multilib/repo packages that might trigger false positives
    if [[ "$pkg" == "steam" ]]; then continue; fi
    if [[ "$pkg" == "lib32-nvidia-utils" ]]; then continue; fi
    
    # Check if package exists in sync db
    if ! pacman -Si "$pkg" &> /dev/null; then
        echo "$pkg"
    fi
done
