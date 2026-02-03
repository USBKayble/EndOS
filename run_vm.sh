#!/usr/bin/env bash

# Configuration
ISO_DIR="out"
DISK_IMAGE="vm_disk.qcow2"
DISK_SIZE="40G"

# Find the latest ISO file in the output directory
ISO_FILE=$(find "$ISO_DIR" -name "*.iso" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -f2- -d" ")

if [ -z "$ISO_FILE" ]; then
    echo "Error: No ISO file found in '$ISO_DIR'."
    echo "Please build the ISO first using ./build.sh"
    exit 1
fi

# Create the disk image if it doesn't exist
if [ ! -f "$DISK_IMAGE" ]; then
    echo "Creating $DISK_SIZE virtual disk image: $DISK_IMAGE"
    qemu-img create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"
fi

echo "Launching $ISO_FILE in QEMU..."
echo "Specs: 8G RAM, 4 vCPUs, KVM enabled, VirtIO GPU with GL, 40GB Disk"

# Launch QEMU
qemu-system-x86_64 \
    -enable-kvm \
    -m 8G \
    -smp 4 \
    -device virtio-vga-gl \
    -display gtk,gl=on \
    -cdrom "$ISO_FILE" \
    -drive file="$DISK_IMAGE",format=qcow2,if=virtio \
    -boot d \
    -usb \
    -device usb-tablet
