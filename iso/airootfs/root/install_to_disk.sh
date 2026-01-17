#!/bin/bash
# EndOS Installer Wrapper
# This script runs archinstall and then injects EndOS specific files for offline setup.

echo "========================================"
echo "      EndOS Disk Installer"
echo "========================================"
echo ""
echo "This wrapper will launch 'archinstall'."
echo "After installation, it will attempt to copy the offline dotfiles"
echo "to the new system so you don't need internet on the first boot."
echo ""
read -p "Press Enter to start installation..."

# Run the official installer
archinstall

# Post-Install Injection
# Archinstall mounts the target at /mnt/archinstall by default (check documentation/behavior)
TARGET_DIR="/mnt/archinstall"

if [ -d "$TARGET_DIR/etc" ]; then
    echo ""
    echo "Installation detected. Injecting EndOS offline files..."
    
    # 1. Create structure
    mkdir -p "$TARGET_DIR/usr/share/endos"
    
    # 2. Copy Dotfiles
    if [ -d "/usr/share/endos/dots" ]; then
        echo "Copying dotfiles repository..."
        cp -a /usr/share/endos/dots "$TARGET_DIR/usr/share/endos/"
    fi
    
    # 3. Copy Setup Script (Removed as setup_arch.sh is deprecated)
    # The dotfiles in /usr/share/endos/dots can be used manually if needed.
    
    echo "Injection complete."
    echo "Files available at /usr/share/endos in the new system."
    
    read -p "Press Enter to exit..."
else
    echo "Target directory $TARGET_DIR not found. Did archinstall unmount it? Files not copied."
fi
