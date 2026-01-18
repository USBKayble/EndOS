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

# Define paths relative to the script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO_DIR="$SCRIPT_DIR/local_repo"
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
# Clean the local repo directory first for a fresh start
echo "Cleaning local repository directory..."
rm -f *.pkg.tar.zst
rm -f local_repo.db* local_repo.files*

# Add all existing packages to the new database
if ls *.pkg.tar.zst 1> /dev/null 2>&1; then
    echo "Adding existing packages to database..."
    repo-add local_repo.db.tar.gz *.pkg.tar.zst
else
    echo "No existing packages found. Database will be created on first add."
fi

# Sync databases using the ISO config to ensure multilib/chaotic-aur are up to date
echo "Syncing package databases..."
if ! echo "$SUDO_PASS" | sudo -S pacman --config "$SCRIPT_DIR/iso/pacman.conf" -Sy --noconfirm 2>&1; then
    echo "Warning: Database sync failed, rebuilding local_repo database..."
    # Rebuild database from any existing packages
    if ls *.pkg.tar.zst 1> /dev/null 2>&1; then
        rm -f local_repo.db* local_repo.files*
        repo-add local_repo.db.tar.gz *.pkg.tar.zst
        echo "Local repository database rebuilt."
    else
        echo "No packages found to rebuild database."
    fi
fi

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

# Function to check if package is installed on system
package_installed() {
    local pkg_name="$1"
    if pacman --config "$SCRIPT_DIR/iso/pacman.conf" -Qi "$pkg_name" &>/dev/null; then
        return 0
    fi
    return 1
}

# Function to install package from local repo to system
install_from_local_repo() {
    local pkg_name="$1"
    local pkg_file
    
    # Find the exact package file
    pkg_file=$(find . -maxdepth 1 -name "${pkg_name}-[0-9]*.pkg.tar.zst" -print -quit)
    
    if [ -z "$pkg_file" ]; then
        echo "  ERROR: Could not find built package for $pkg_name"
        return 1
    fi
    
    echo "  Installing $pkg_name from local repo to satisfy dependencies..."
    if ! echo "$SUDO_PASS" | sudo -S pacman -U --noconfirm --config "$SCRIPT_DIR/iso/pacman.conf" "$pkg_file" >> "$LOG_FILE" 2>&1; then
        echo "  WARNING: Failed to install $pkg_name locally. Subsequent builds might fail if they depend on this."
        return 1
    fi
    
    # Sync pacman database to ensure package is properly registered
    echo "  Syncing pacman database after installing $pkg_name..."
    if ! echo "$SUDO_PASS" | sudo -S pacman -Sy --noconfirm --config "$SCRIPT_DIR/iso/pacman.conf" >> "$LOG_FILE" 2>&1; then
        echo "  WARNING: Failed to sync pacman database after installing $pkg_name."
    fi
    
    echo "  Successfully installed $pkg_name"
    return 0
}

echo "Scanning for missing packages..."

# Create a temporary file with dependency ordering
TEMP_PACKAGES_FILE=$(mktemp)
echo "Creating dependency-ordered package list..."

# Create dependency tracking
MILLENNIUM_DEPS=("lib32-python311-bin" "steam")

# Add millennium dependencies first, then millennium
while IFS= read -r package; do
    # Skip empty lines and comments
    [[ -z "$package" || "$package" =~ ^# ]] && continue
    
    # If this is millennium, add its dependencies first
    if [ "$package" == "millennium" ]; then
        for dep in "${MILLENNIUM_DEPS[@]}"; do
            echo "$dep" >> "$TEMP_PACKAGES_FILE"
        done
    fi
    
    # Add package itself
    echo "$package" >> "$TEMP_PACKAGES_FILE"
done < "$PACKAGES_FILE"

# Process packages in dependency order
while IFS= read -r package; do
    # Skip empty lines and comments
    [[ -z "$package" || "$package" =~ ^# ]] && continue

    if package_exists "$package"; then
        echo "Skipping $package (already exists)"
        continue
    fi

    echo "Processing package: $package"
    
    # Special handling for millennium dependencies - install if built but not installed
    for dep in "${MILLENNIUM_DEPS[@]}"; do
        if [ "$package" == "millennium" ] && package_exists "$dep" && ! package_installed "$dep"; then
            echo "  NOTE: Installing dependency $dep before building $package"
            install_from_local_repo "$dep"
        fi
    done

    # Force AUR build for certain packages that are only available in AUR
    FORCE_AUR_PACKAGES=("google-breakpad")
    FORCE_AUR=false
    for force_pkg in "${FORCE_AUR_PACKAGES[@]}"; do
        if [ "$package" == "$force_pkg" ]; then
            FORCE_AUR=true
            echo "  NOTE: Forcing AUR build for $package (not available in official repos)"
            break
        fi
    done

    # Check if package exists in official repos
    if [ "$FORCE_AUR" = false ] && pacman --config "$SCRIPT_DIR/iso/pacman.conf" -Si "$package" &>/dev/null; then
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
        elif [ "$package" == "ttf-material-symbols-variable-git" ]; then
            AUR_PKG_NAME="material-symbols-git"
            echo "  NOTE: Mapped $package to AUR package $AUR_PKG_NAME"
        elif [ "$package" == "qt6-avif-image-plugin" ]; then
            AUR_PKG_NAME="qt5-avif-image-plugin"
            echo "  NOTE: Mapped $package to AUR package $AUR_PKG_NAME (AUR uses qt5-avif-image-plugin name)"
        fi

        # Remove any existing directory just in case
        rm -rf "$AUR_PKG_NAME"
        
        # Try git clone with better error handling
        if git clone "https://aur.archlinux.org/${AUR_PKG_NAME}.git" 2>> "$LOG_FILE"; then
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
                echo "  ERROR: PKGBUILD missing in $BUILDPKG_DIR - AUR package may be invalid or renamed"
                echo "  TIP: Check https://aur.archlinux.org/packages/${AUR_PKG_NAME} for package status"
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
                echo "  Successfully built $package"
                
                # Capture generated package files
                built_pkgs=( *.pkg.tar.zst )
                mv *.pkg.tar.zst ../
                cd ..
                rm -rf "$BUILDPKG_DIR"
                
                # Immediately add to repo and sync so dependencies are available for next builds
                echo "  Adding $package to local_repo database and syncing..."
                for pkg in "${built_pkgs[@]}"; do
                    repo-add local_repo.db.tar.gz "$pkg" >> "$LOG_FILE" 2>&1
                done
                
                # Sync pacman to pick up the new local package
                if ! echo "$SUDO_PASS" | sudo -S pacman --config "$SCRIPT_DIR/iso/pacman.conf" -Sy --noconfirm >> "$LOG_FILE" 2>&1; then
                     echo "  WARNING: Failed to sync pacman database after adding $package."
                fi

                # Install the package locally so makepkg can find it as a dependency
                echo "  Installing $package locally to satisfy dependencies..."
                if ! echo "$SUDO_PASS" | sudo -S pacman -U --noconfirm "${built_pkgs[@]}" >> "$LOG_FILE" 2>&1; then
                    echo "  WARNING: Failed to install $package locally. Subsequent builds might fail if they depend on this."
                fi
                
                NEWLY_BUILT=true
            else
                echo "  Failed to build $package. See log."
                FAILED_PACKAGES+=("$package")
                cd ..
                rm -rf "$BUILDPKG_DIR"
            fi
        else
            echo "  Failed to fetch $package from AUR. See log."
            echo "  DEBUG: Git clone failed for ${AUR_PKG_NAME}" >> "$LOG_FILE"
            echo "  TIP: This could be a network issue or the package may not exist in AUR"
            echo "  TIP: Check https://aur.archlinux.org/packages/${AUR_PKG_NAME} for package status"
            FAILED_PACKAGES+=("$package")
        fi
    fi
done < "$TEMP_PACKAGES_FILE"

# Clean up temporary file
rm -f "$TEMP_PACKAGES_FILE"

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
