#!/usr/bin/env bash
# Disk Detection Script for EndOS Installer
# Detects all available disks and their properties

# Output JSON array of disks

disks_json="["
first=true

for disk in $(lsblk -d -n -o NAME,TYPE | grep "disk" | awk '{print $1}'); do
    # Get disk information
    size=$(lsblk -d -n -o SIZE "/dev/$disk" | xargs)
    type=$(lsblk -d -n -o ROTA "/dev/$disk" | xargs)
    model=$(lsblk -d -n -o MODEL "/dev/$disk" | xargs)
    
    # Determine disk type
    if [ "$type" = "0" ]; then
        disk_type="SSD"
    else
        disk_type="HDD"
    fi
    
    # Build JSON entry
    if [ "$first" = true ]; then
        first=false
    else
        disks_json+=","
    fi
    
    disks_json+="{\"path\":\"/dev/$disk\",\"size\":\"$size\",\"type\":\"$disk_type\",\"model\":\"$model\",\"displayName\":\"$disk - $size ($disk_type)\"}"
done

disks_json+="]"

echo "$disks_json"
