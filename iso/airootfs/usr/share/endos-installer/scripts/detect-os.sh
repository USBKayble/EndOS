#!/usr/bin/env bash
# OS Detection Script for EndOS Installer
# Detects existing operating systems on a disk

DISK=$1

if [ -z "$DISK" ]; then
    echo "[]"
    exit 0
fi

# Array to hold detected OS
os_array="["
first=true

# Use os-prober if available
if command -v os-prober &> /dev/null; then
    os-prober | while IFS=: read -r partition label type; do
        if [ "$first" = true ]; then
            first=false
        else
            os_array+=","
        fi
        
        os_array+="{\"name\":\"$label\",\"partition\":\"$partition\",\"type\":\"$type\"}"
    done
else
    # Fallback: check for common boot indicators
    for part in $(lsblk -ln -o NAME "$DISK" | grep -v "^$(basename "$DISK")$"); do
        part_dev="/dev/$part"
        
        # Mount partition temporarily to check
        mount_point=$(mktemp -d)
        if mount -o ro "$part_dev" "$mount_point" 2>/dev/null; then
            os_name=""
            
            # Check for Windows
            if [ -f "$mount_point/Windows/System32/winload.exe" ] || [ -f "$mount_point/bootmgr" ]; then
                os_name="Windows"
            # Check for Linux
            elif [ -d "$mount_point/etc" ] && [ -f "$mount_point/etc/os-release" ]; then
                os_name=$(grep "^NAME=" "$mount_point/etc/os-release" | cut -d'"' -f2)
            # Check for macOS
            elif [ -d "$mount_point/System/Library/CoreServices" ]; then
                os_name="macOS"
            fi
            
            umount "$mount_point" 2>/dev/null
            rmdir "$mount_point" 2>/dev/null
            
            if [ -n "$os_name" ]; then
                if [ "$first" = true ]; then
                    first=false
                else
                    os_array+=","
                fi
                
                os_array+="{\"name\":\"$os_name\",\"partition\":\"$part_dev\",\"type\":\"unknown\"}"
            fi
        else
            rmdir "$mount_point" 2>/dev/null
        fi
    done
fi

os_array+="]"
echo "$os_array"
