#!/bin/bash
set -e

# extract_dots_packages.sh
# Extracts dependencies from dots-hyprland and adds them to ISO config
# handling deduplication.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="$SCRIPT_DIR/dots-hyprland"
ISO_PACKAGES_FILE="$SCRIPT_DIR/iso/packages.x86_64"
ISO_REQ_FILE="$SCRIPT_DIR/iso/requirements.txt"
DOTS_REQ_FILE="$DOTS_DIR/sdata/uv/requirements.txt"

# --- Python Requirements Extraction ---
echo "Processing Python requirements..."
if [ -f "$DOTS_REQ_FILE" ]; then
    # Ensure destination file exists
    touch "$ISO_REQ_FILE"
    
    # Read existing requirements into an associative array for fast lookup
    declare -A existing_reqs
    while IFS= read -r line; do
        # Strip comments and whitespace
        clean_line=$(echo "$line" | sed 's/#.*//' | xargs)
        [ -z "$clean_line" ] && continue
        existing_reqs["$clean_line"]=1
    done < "$ISO_REQ_FILE"

    while IFS= read -r line; do
        clean_line=$(echo "$line" | sed 's/#.*//' | xargs)
        [ -z "$clean_line" ] && continue
        
        if [ -z "${existing_reqs[$clean_line]}" ]; then
            echo "  Adding python requirement: $clean_line"
            echo "$clean_line" >> "$ISO_REQ_FILE"
            existing_reqs["$clean_line"]=1
        else
            echo "  Skipping duplicate python requirement: $clean_line"
        fi
    done < "$DOTS_REQ_FILE"
else
    echo "Warning: $DOTS_REQ_FILE not found."
fi

# --- Arch Package Extraction ---
echo "Processing Arch packages..."

# List of component directories from dots-hyprland install-deps.sh
# We expand the brace expansion manually or use a loop that handles it.
# Based on analysis:
COMPONENT_DIRS=(
    "sdata/dist-arch/illogical-impulse-audio"
    "sdata/dist-arch/illogical-impulse-backlight"
    "sdata/dist-arch/illogical-impulse-basic"
    "sdata/dist-arch/illogical-impulse-fonts-themes"
    "sdata/dist-arch/illogical-impulse-kde"
    "sdata/dist-arch/illogical-impulse-portal"
    "sdata/dist-arch/illogical-impulse-python"
    "sdata/dist-arch/illogical-impulse-screencapture"
    "sdata/dist-arch/illogical-impulse-toolkit"
    "sdata/dist-arch/illogical-impulse-widgets"
    "sdata/dist-arch/illogical-impulse-hyprland"
    "sdata/dist-arch/illogical-impulse-microtex-git"
    "sdata/dist-arch/illogical-impulse-quickshell-git"
    "sdata/dist-arch/illogical-impulse-bibata-modern-classic-bin"
)

# Read existing packages into an associative array
declare -A existing_pkgs
if [ -f "$ISO_PACKAGES_FILE" ]; then
    while IFS= read -r line; do
        clean_line=$(echo "$line" | sed 's/#.*//' | xargs)
        [ -z "$clean_line" ] && continue
        existing_pkgs["$clean_line"]=1
    done < "$ISO_PACKAGES_FILE"
fi

for comp_rel_path in "${COMPONENT_DIRS[@]}"; do
    comp_path="$DOTS_DIR/$comp_rel_path"
    pkgbuild="$comp_path/PKGBUILD"
    
    if [ -f "$pkgbuild" ]; then
        echo "  Scanning $comp_rel_path..."
        # Extract depends array using a subshell to avoid polluting current env
        # We assume standard PKGBUILD format: depends=(...)
        # We used 'source' safely because we control the input (it's our local file)
        # but capturing the array content is tricky if we don't want to execute code.
        # However, these are simple data PKGBUILDs.
        
        (
            source "$pkgbuild"
            # Print each element of depends array
            for dep in "${depends[@]}"; do
                echo "$dep"
            done
        ) | while IFS= read -r dep; do
            clean_dep=$(echo "$dep" | xargs)
            [ -z "$clean_dep" ] && continue
            
            if [ -z "${existing_pkgs[$clean_dep]}" ]; then
                echo "    Adding package: $clean_dep"
                echo "$clean_dep" >> "$ISO_PACKAGES_FILE"
                existing_pkgs["$clean_dep"]=1
            else
                 # Verbose: echo "    Skipping duplicate package: $clean_dep"
                 :
            fi
        done
    else
        echo "  Warning: PKGBUILD not found in $comp_path"
    fi
done

echo "Dependency extraction and merge complete."
