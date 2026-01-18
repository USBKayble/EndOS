#!/bin/bash

# Script to create a local repository
# This ensures that mkarchiso uses only the local repository
# Always starts fresh - local_repo is completely rebuilt each run

# Exit on error
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root."
    echo "Please run: sudo $0"
    exit 1
fi

# Keep-alive: update existing sudo time stamp if set, otherwise do nothing.
while true; do sudo -v; sleep 10; kill -0 "$$" || exit; done 2>/dev/null &

# AUR build function
build_aur_package() {
    local package="$1"
    local AUR_PKG_NAME="$package"

    # Mapping for renamed packages
    case "$package" in
        otf-space-grotesk) AUR_PKG_NAME="38c3-styles" ;;
        ttf-material-symbols-variable-git) AUR_PKG_NAME="material-symbols-git" ;;
        qt6-avif-image-plugin) AUR_PKG_NAME="qt5-avif-image-plugin" ;;
    esac

    # Clean up any previous attempts
    rm -rf "$AUR_PKG_NAME"

    echo "  Cloning $AUR_PKG_NAME from AUR..."
    if ! git clone "https://aur.archlinux.org/${AUR_PKG_NAME}.git" 2>> "$LOG_FILE"; then
        echo "  ERROR: Failed to clone $AUR_PKG_NAME"
        FAILED_PACKAGES+=("$package")
        return 1
    fi

    cd "$AUR_PKG_NAME"

    # Hotfix for 38c3-styles
    if [ "$AUR_PKG_NAME" == "38c3-styles" ]; then
        echo "  Applying hotfix for 38c3-styles..."
        sed -i "/'html2markdown'/d" PKGBUILD 2>/dev/null || true
        sed -i "/html2markdown --input/d" PKGBUILD 2>/dev/null || true
        sed -i "s/ website.md//g" PKGBUILD 2>/dev/null || true
    fi

    echo "  Building $package..."
    if makepkg -sc --noconfirm >> "$LOG_FILE" 2>&1; then
        echo "  Successfully built $package"
        mv *.pkg.tar.zst ../
        cd ..
        rm -rf "$AUR_PKG_NAME"
        ((BUILT_COUNT++))
    else
        echo "  ERROR: Failed to build $package"
        cd ..
        rm -rf "$AUR_PKG_NAME"
        FAILED_PACKAGES+=("$package")
    fi
}

# Official package download function
download_official_package() {
    local package="$1"

    # Clean up any partials
    rm -f "$package"*.part "$package"*.pkg.tar.zst 2>/dev/null || true

    if pacman -Sw --noconfirm --cachedir . "$package" >> "$LOG_FILE" 2>&1; then
        echo "  Downloaded $package"
        ((BUILT_COUNT++))
    else
        echo "  ERROR: Failed to download $package"
        FAILED_PACKAGES+=("$package")
    fi
}

echo "Starting local repository creation..."

# Define paths relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO_DIR="$SCRIPT_DIR/local_repo"
PACKAGES_FILE="$SCRIPT_DIR/iso/packages.x86_64"

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: $PACKAGES_FILE not found!"
    exit 1
fi

# Clean and create local_repo directory
echo "Cleaning and creating local repository directory..."
rm -rf "$LOCAL_REPO_DIR"
mkdir -p "$LOCAL_REPO_DIR"
cd "$LOCAL_REPO_DIR"

# Sync databases using system pacman
echo "Syncing package databases..."
pacman -Sy --noconfirm

LOG_FILE="$SCRIPT_DIR/repo_build.log"
echo "Log file: $LOG_FILE"
: > "$LOG_FILE"

FAILED_PACKAGES=()
BUILT_COUNT=0

echo "Scanning packages file..."

# Track packages that need AUR (not in official repos)
AUR_PACKAGES=(
    "adw-gtk-theme-git"
    "breeze-plus"
    "darkly-bin"
    "matugen-bin"
    "otf-space-grotesk"
    "ttf-material-symbols-variable-git"
    "ttf-readex-pro"
    "ttf-rubik-vf"
    "ttf-twemoji"
    "wlogout"
    "google-breakpad"
    "qt6-avif-image-plugin"
)

# Create a set for fast lookup
declare -A AUR_PACKAGE_SET
for pkg in "${AUR_PACKAGES[@]}"; do
    AUR_PACKAGE_SET[$pkg]=1
done

# Process packages
while IFS= read -r package; do
    # Skip empty lines and comments
    [[ -z "$package" || "$package" =~ ^# ]] && continue

    echo "Processing package: $package"
    echo "------------------------------------------------" >> "$LOG_FILE"
    echo "Processing $package" >> "$LOG_FILE"

    # Check if this is an AUR package
    if [[ -n "${AUR_PACKAGE_SET[$package]}" ]]; then
        echo "  Building from AUR..."
        build_aur_package "$package"
    else
        echo "  Downloading from official repos..."
        download_official_package "$package"
    fi

done < "$PACKAGES_FILE"

# Finalize database
echo "Finalizing local repository database..."
repo-add local_repo.db.tar.gz *.pkg.tar.zst 2>/dev/null || true

echo "Local repository creation completed."
echo "Built $BUILT_COUNT packages successfully."

if [ ${#FAILED_PACKAGES[@]} -ne 0 ]; then
    echo "------------------------------------------------"
    echo "WARNING: The following packages failed:"
    for failed in "${FAILED_PACKAGES[@]}"; do
        echo "  - $failed"
    done
    echo "See $LOG_FILE for details."
    echo "------------------------------------------------"
    exit 1
else
    echo "All packages built successfully!"
fi
