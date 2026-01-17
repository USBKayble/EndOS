#!/bin/bash
# util/collect_packages.sh

# This script iterates over the buildpkg directories in dots-hyprland-main
# and extracts the dependencies (packages) to be installed.
# Output: A raw list of package names (one per line).

DOTS_ROOT="${1:-dots-hyprland-main/dots-hyprland-main}"

if [ ! -d "$DOTS_ROOT" ]; then
    if [ -d "sdata/dist-arch" ]; then
        DOTS_ROOT="."
    else
        echo "Error: Cannot find $DOTS_ROOT" >&2
        exit 1
    fi
fi

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
)

extract_deps() {
    local pkg_dir="$1"
    local full_path="$DOTS_ROOT/sdata/dist-arch/$pkg_dir"
    
    if [ -f "$full_path/PKGBUILD" ]; then
        (
            epoch=""; pkgver="" ; pkgrel=""; pkgdesc=""; arch=(); url=""; license=()
            depends=(); optdepends=(); makedepends=()
            
            source "$full_path/PKGBUILD"
            for dep in "${depends[@]}"; do
                echo "$dep"
            done
        )
    fi
}

for pkg in "${METAPKGS[@]}"; do
    extract_deps "$pkg"
done | sort -u | grep -vE "^$"
