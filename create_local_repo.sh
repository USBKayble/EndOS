#!/bin/bash

# Script to create a local repository using yay
# This ensures that mkarchiso uses only the local repository

# Exit on error
set -e

echo "Starting local repository creation..."

# Ask for sudo upfront and capture password
read -s -p "Enter sudo password: " SUDO_PASS
echo
# Verify password
if ! echo "$SUDO_PASS" | sudo -S -v 2>/dev/null; then
    echo "Incorrect password."
    exit 1
fi

echo "Syncing package databases..."
echo "$SUDO_PASS" | sudo -S pacman -Sy --noconfirm

# Keep-alive: update existing sudo time stamp if set, otherwise do nothing.
while true; do echo "$SUDO_PASS" | sudo -S -v; sleep 10; kill -0 "$$" || exit; done 2>/dev/null &

# Define paths relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO_DIR="$SCRIPT_DIR/iso/local_repo"
PACKAGES_FILE="$SCRIPT_DIR/iso/packages.x86_64"

# Create a directory for the local repository
mkdir -p "$LOCAL_REPO_DIR"

if [ ! -f "$PACKAGES_FILE" ]; then
    echo "Error: $PACKAGES_FILE not found!"
    exit 1
fi

# Navigate to the local repository directory
cd "$LOCAL_REPO_DIR" || exit 1

# Initialize a local repository
echo "Initializing local repository..."
# Check if db exists, if not maybe touch it or wait until we have packages?
# repo-add needs packages usually. We'll skip empty init if it's problematic, 
# but for now preserving original intent but handling potential failure if valid.
if [ ! -f "local_repo.db.tar.gz" ]; then
    echo "No existing DB found. Will be created when packages are added."
fi

# Sync databases using the ISO config to ensure multilib/chaotic-aur are up to date
echo "Syncing package databases..."
echo "$SUDO_PASS" | sudo -S pacman --config "$SCRIPT_DIR/iso/pacman.conf" -Sy --noconfirm

LOG_FILE="$SCRIPT_DIR/repo_build.log"
echo "Log file: $LOG_FILE"
: > "$LOG_FILE"

FAILED_PACKAGES=()
NEWLY_BUILT=false

# Function to check if package exists in local repo dir
package_exists() {
    local pkg_name="$1"
    # Look for package file starting with name and having .pkg.tar.zst extension
    # We use find to avoid shell expansion issues if no files exist
    if find . -maxdepth 1 -name "${pkg_name}-[0-9]*.pkg.tar.zst" -print -quit | grep -q .; then
        return 0
    fi
    return 1
}

echo "Scanning for missing packages..."

while IFS= read -r package; do
    # Skip empty lines and comments
    [[ -z "$package" || "$package" =~ ^# ]] && continue

    if package_exists "$package"; then
        echo "Skipping $package (already exists)"
        continue
    fi

    echo "Processing package: $package"

    # Check if package exists in official repos
    if pacman --config "$SCRIPT_DIR/iso/pacman.conf" -Si "$package" &>/dev/null; then
        echo "  Downloading from official repos..."
        echo "------------------------------------------------" >> "$LOG_FILE"
        echo "Downloading $package" >> "$LOG_FILE"
        
        # Clean up potential partials or existing root-owned files that might block writing
        echo "$SUDO_PASS" | sudo -S rm -f "$package"*.part "$package"*.pkg.tar.zst
        
        if ! echo "$SUDO_PASS" | sudo -S pacman --config "$SCRIPT_DIR/iso/pacman.conf" -Sw --noconfirm --cachedir . "$package" >> "$LOG_FILE" 2>&1; then
             echo "  Failed to download $package. See log."
             FAILED_PACKAGES+=("$package")
        else
             NEWLY_BUILT=true
        fi
    else
        echo "  Package not in official repos, assuming AUR..."
        echo "------------------------------------------------" >> "$LOG_FILE"
        echo "Building AUR package $package" >> "$LOG_FILE"
        
        # Clean up any previous attempts
        rm -rf "$package"
        
        # Download PKGBUILD using git clone (more reliable than yay -G for scripting)
        echo "  Downloading PKGBUILD for $package via git..."
        
        # Mapping for packages that are part of a split package or renamed in AUR
        AUR_PKG_NAME="$package"
        if [ "$package" == "otf-space-grotesk" ]; then
            AUR_PKG_NAME="38c3-styles"
            echo "  NOTE: Mapped $package to AUR package $AUR_PKG_NAME"
        fi

        # Remove any existing directory just in case
        rm -rf "$AUR_PKG_NAME"
        
        if git clone "https://aur.archlinux.org/${AUR_PKG_NAME}.git"; then
            echo "  DEBUG: git clone completed." >> "$LOG_FILE"
            
            BUILDPKG_DIR="$AUR_PKG_NAME"
            
            echo "  DEBUG: Detected build directory: '$BUILDPKG_DIR'" >> "$LOG_FILE"

            if [ -z "$BUILDPKG_DIR" ] || [ ! -d "$BUILDPKG_DIR" ]; then
                 echo "  ERROR: Could not detect build directory for $package."
                 echo "  ERROR: Could not detect build directory for $package." >> "$LOG_FILE"
                 FAILED_PACKAGES+=("$package")
                 continue
            fi
            
            cd "$BUILDPKG_DIR" || { 
                echo "  Failed to enter directory $BUILDPKG_DIR"
                FAILED_PACKAGES+=("$package")
                continue
            }
            
            echo "  DEBUG: Entered directory $(pwd)" >> "$LOG_FILE"
            echo "  DEBUG: Directory content:" >> "$LOG_FILE"
            ls -la >> "$LOG_FILE"
            
            # Additional check for PKGBUILD presence
            if [ ! -f "PKGBUILD" ]; then
                echo "  ERROR: PKGBUILD missing after git clone." >> "$LOG_FILE"
                echo "  ERROR: PKGBUILD missing in $BUILDPKG_DIR"
                cd ..
                FAILED_PACKAGES+=("$package")
                continue
            fi
            
            # Hotfix for 38c3-styles: remove AUR dependency 'html2markdown' used for docs
            if [ "$AUR_PKG_NAME" == "38c3-styles" ]; then
                echo "  Applying hotfix for 38c3-styles (removing html2markdown dependency)..."
                echo "  DEBUG: Patching PKGBUILD to remove html2markdown..." >> "$LOG_FILE"
                sed -i "/'html2markdown'/d" PKGBUILD
                sed -i "/html2markdown --input/d" PKGBUILD
                sed -i "s/ website.md//g" PKGBUILD
            fi
            
            # Build package
            echo "  Building $package..."
            # -s: install deps, -c: clean, --noconfirm
            if makepkg -sc --noconfirm >> "$LOG_FILE" 2>&1; then
                # Move built package to repo dir
                mv *.pkg.tar.zst ../
                cd ..
                rm -rf "$BUILDPKG_DIR"
                echo "  Successfully built $package"
                NEWLY_BUILT=true
            else
                echo "  Failed to build $package. See log."
                FAILED_PACKAGES+=("$package")
                cd ..
                rm -rf "$BUILDPKG_DIR"
            fi
        else
            echo "  Failed to fetch $package from AUR. See log."
            FAILED_PACKAGES+=("$package")
        fi
    fi
done < "$PACKAGES_FILE"

# Add the downloaded packages to the local repository
if [ "$NEWLY_BUILT" = true ]; then
    echo "Adding packages to the local repository..."
    # Batch add all packages to the DB to save time
    # repo-add is smart enough to update existing or add new
    repo-add local_repo.db.tar.gz *.pkg.tar.zst >> "$LOG_FILE" 2>&1
else
    echo "No new packages to add."
fi

echo "Local repository creation completed."

if [ ${#FAILED_PACKAGES[@]} -ne 0 ]; then
    echo "------------------------------------------------"
    echo "WARNING: The following packages failed to process:"
    for failed in "${FAILED_PACKAGES[@]}"; do
        echo "  - $failed"
        # Print last 2 lines of log for this failure if possible? 
        # Hard to map exactly, but user can check log.
    done
    echo "See $LOG_FILE for details."
    echo "------------------------------------------------"
    exit 1
else
    echo "All packages processed successfully."
fi
