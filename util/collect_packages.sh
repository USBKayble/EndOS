#!/bin/bash
# util/collect_packages.sh

# This script iterates over the buildpkg directories in dots-hyprland-main
# and extracts the dependencies (packages) to be installed.
# It mimics the logic of install-deps.sh but prints the packages for ISO build.

# Path to the dots-hyprland-main repo (inner folder)
# We accept an optional argument for the dots root, otherwise default
DOTS_ROOT="${1:-dots-hyprland-main/dots-hyprland-main}"
FILTER_MODE="all" # all, repo, aur

# Handle flags
if [[ "$1" == "--repo-only" ]]; then
    FILTER_MODE="repo"
    shift
    DOTS_ROOT="${1:-dots-hyprland-main/dots-hyprland-main}"
elif [[ "$1" == "--aur-only" ]]; then
    FILTER_MODE="aur"
    shift
    DOTS_ROOT="${1:-dots-hyprland-main/dots-hyprland-main}"
fi

# Determine absolute path if possible or verify existence
if [ ! -d "$DOTS_ROOT" ]; then
    # Fallback: check if we are already inside the repo structure or airootfs
    if [ -d "sdata/dist-arch" ]; then
        DOTS_ROOT="."
    else
        echo "Error: Cannot find $DOTS_ROOT" >&2
        exit 1
    fi
fi

# List of metapackages as defined in install-deps.sh
METAPKGS=(
    "illogical-impulse-audio"
    "illogical-impulse-backlight"
    "illogical-impulse-basic"
    "illogical-impulse-fonts-themes"
    "illogical-impulse-kde"
    "illogical-impulse-portal"
    "illogical-impulse-python"
    "illogical-impulse-screencapture"
    "illogical-impulse-toolkit"
    "illogical-impulse-widgets"
    "illogical-impulse-hyprland"
    "illogical-impulse-microtex-git"
    "illogical-impulse-quickshell-git"
    "illogical-impulse-bibata-modern-classic-bin"
    # "illogical-impulse-oneui4-icons-git" # Commented out in install-deps.sh
)

# Function to extract deps
extract_deps() {
    local pkg_dir="$1"
    local full_path="$DOTS_ROOT/sdata/dist-arch/$pkg_dir"
    
    if [ -f "$full_path/PKGBUILD" ]; then
        # Run in subshell to avoid polluting vars
        (
            epoch=""; pkgver="" ; pkgrel=""; pkgdesc=""; arch=(); url=""; license=()
            depends=(); optdepends=(); makedepends=()
            
            source "$full_path/PKGBUILD"
            for dep in "${depends[@]}"; do
                echo "$dep"
            done
        )
    else
        echo "Warning: PKGBUILD not found in $full_path" >&2
    fi
}

# Collect all deps first
ALL_DEPS=$(for pkg in "${METAPKGS[@]}"; do extract_deps "$pkg"; done | sort -u | grep -vE "^$")

if [[ "$FILTER_MODE" == "all" ]]; then
    echo "$ALL_DEPS"
    exit 0
fi

# Check pacman availability
if ! command -v pacman &> /dev/null; then
    echo "Error: pacman not found, cannot filter packages." >&2
    exit 1
fi

# Filter Loop
for dep in $ALL_DEPS; do
    if pacman -Si "$dep" &> /dev/null; then
        # It is in Repo
        if [[ "$FILTER_MODE" == "repo" ]]; then
            echo "$dep"
        fi
    else
        # It is NOT in Repo (Assume AUR)
        if [[ "$FILTER_MODE" == "aur" ]]; then
            echo "$dep"
        fi
    fi
done
