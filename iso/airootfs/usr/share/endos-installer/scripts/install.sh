#!/usr/bin/env bash
# EndOS Installation Script
# Handles the complete system installation process

set -euo pipefail

# Check for dry-run mode
DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
    shift
fi

# Configuration file passed as argument
CONFIG_FILE=$1

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Dry-run wrapper functions
run_cmd() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would run: $*"
        sleep 0.1  # Small delay to simulate work
    else
        "$@"
    fi
}

run_silent() {
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would run silently: $*"
    else
        "$@" > /dev/null 2>&1
    fi
}

# Read configuration
LANGUAGE=$(jq -r '.language' "$CONFIG_FILE")
TIMEZONE=$(jq -r '.timezone' "$CONFIG_FILE")
KEYBOARD=$(jq -r '.keyboardLayout' "$CONFIG_FILE")
DISK=$(jq -r '.disk.device' "$CONFIG_FILE")
INSTALL_MODE=$(jq -r '.disk.mode' "$CONFIG_FILE")
PARTITION_SIZE=$(jq -r '.disk.partitionSize // 50' "$CONFIG_FILE")
USERNAME=$(jq -r '.user.username' "$CONFIG_FILE")
PASSWORD=$(jq -r '.user.password' "$CONFIG_FILE")
HOSTNAME=$(jq -r '.hostname' "$CONFIG_FILE")
INSTALL_PACKAGES=$(jq -r '.packages.optional | join(" ")' "$CONFIG_FILE")
CUSTOM_PACKAGES=$(jq -r '.packages.custom | join(" ")' "$CONFIG_FILE")
NEEDS_NVIDIA=$(jq -r '.hardware.needsNvidiaDriver' "$CONFIG_FILE")
NEEDS_AMD=$(jq -r '.hardware.needsAMDDriver' "$CONFIG_FILE")

# Progress reporting function
progress() {
    local percent=$1
    local message=$2
    echo "PROGRESS:$percent:$message"
}

# Emit progress messages
progress 0 "Starting installation..."

# Step 1: Partition disk
progress 5 "Partitioning disk..."

if [ "$INSTALL_MODE" = "auto" ] || [ "$INSTALL_MODE" = "dualboot" ]; then
    # Determine if we're using UEFI or BIOS
    if [ -d /sys/firmware/efi ]; then
        BOOT_MODE="UEFI"
        
        # Create GPT partition table
        run_cmd parted -s "$DISK" mklabel gpt
        
        if [ "$INSTALL_MODE" = "auto" ]; then
            # Full disk installation
            run_cmd parted -s "$DISK" mkpart primary fat32 1MiB 513MiB
            run_cmd parted -s "$DISK" set 1 esp on
            run_cmd parted -s "$DISK" mkpart primary ext4 513MiB 100%
            
            BOOT_PART="${DISK}1"
            ROOT_PART="${DISK}2"
        else
            # Dual boot - resize existing partitions and create new ones
            # Get total disk size
            if [ "$DRY_RUN" = true ]; then
                DISK_SIZE_GB=500  # Mock 500GB disk for dry-run
            else
                DISK_SIZE=$(blockdev --getsize64 "$DISK")
                DISK_SIZE_GB=$((DISK_SIZE / 1024 / 1024 / 1024))
            fi
            
            # Calculate partition sizes
            ENDOS_SIZE=$((DISK_SIZE_GB * PARTITION_SIZE / 100))
            
            # Check if EFI partition exists
            if [ "$DRY_RUN" = true ]; then
                # Mock: assume no existing EFI partition for dry-run
                BOOT_PART="/dev/sda1"
                ROOT_PART="/dev/sda2"
                run_cmd parted -s "$DISK" mkpart primary fat32 "$((DISK_SIZE_GB - ENDOS_SIZE))GiB" "$((DISK_SIZE_GB - ENDOS_SIZE + 1))GiB"
                run_cmd parted -s "$DISK" mkpart primary ext4 "$((DISK_SIZE_GB - ENDOS_SIZE + 1))GiB" 100%
            elif lsblk -no PARTTYPE "$DISK" | grep -qi "c12a7328-f81f-11d2-ba4b-00a0c93ec93b"; then
                BOOT_PART=$(lsblk -ln -o NAME,PARTTYPE "$DISK" | grep -i "c12a7328-f81f-11d2-ba4b-00a0c93ec93b" | head -n1 | awk '{print "/dev/"$1}')
                
                # Create root partition in remaining space
                run_cmd parted -s "$DISK" mkpart primary ext4 "$((DISK_SIZE_GB - ENDOS_SIZE))GiB" 100%
                ROOT_PART=$(lsblk -ln -o NAME "$DISK" | tail -n1 | awk '{print "/dev/"$1}')
            else
                # No EFI partition, create one
                run_cmd parted -s "$DISK" mkpart primary fat32 "$((DISK_SIZE_GB - ENDOS_SIZE))GiB" "$((DISK_SIZE_GB - ENDOS_SIZE + 1))GiB"
                if [ "$DRY_RUN" = false ]; then
                    parted -s "$DISK" set $(lsblk -ln -o NAME "$DISK" | tail -n1 | sed 's/[^0-9]//g') esp on
                    BOOT_PART=$(lsblk -ln -o NAME "$DISK" | tail -n1 | awk '{print "/dev/"$1}')
                else
                    BOOT_PART="/dev/sda1"  # Mock for dry-run
                fi
                
                # Create root partition
                run_cmd parted -s "$DISK" mkpart primary ext4 "$((DISK_SIZE_GB - ENDOS_SIZE + 1))GiB" 100%
                if [ "$DRY_RUN" = false ]; then
                    ROOT_PART=$(lsblk -ln -o NAME "$DISK" | tail -n1 | awk '{print "/dev/"$1}')
                else
                    ROOT_PART="/dev/sda2"  # Mock for dry-run
                fi
            fi
        fi
    else
        BOOT_MODE="BIOS"
        
        # Create MBR partition table
        run_cmd parted -s "$DISK" mklabel msdos
        
        if [ "$INSTALL_MODE" = "auto" ]; then
            run_cmd parted -s "$DISK" mkpart primary ext4 1MiB 100%
            run_cmd parted -s "$DISK" set 1 boot on
            
            ROOT_PART="${DISK}1"
            BOOT_PART=""
        else
            # Dual boot
            if [ "$DRY_RUN" = true ]; then
                DISK_SIZE_GB=500  # Mock 500GB disk for dry-run
            else
                DISK_SIZE=$(blockdev --getsize64 "$DISK")
                DISK_SIZE_GB=$((DISK_SIZE / 1024 / 1024 / 1024))
            fi
            ENDOS_SIZE=$((DISK_SIZE_GB * PARTITION_SIZE / 100))
            
            run_cmd parted -s "$DISK" mkpart primary ext4 "$((DISK_SIZE_GB - ENDOS_SIZE))GiB" 100%
            if [ "$DRY_RUN" = false ]; then
                parted -s "$DISK" set $(lsblk -ln -o NAME "$DISK" | tail -n1 | sed 's/[^0-9]//g') boot on
                ROOT_PART=$(lsblk -ln -o NAME "$DISK" | tail -n1 | awk '{print "/dev/"$1}')
            else
                ROOT_PART="/dev/sda1"  # Mock for dry-run
            fi
            BOOT_PART=""
        fi
    fi
    
    # Wait for partition table to update
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would wait for partition table update"
    else
        sleep 2
        partprobe "$DISK"
        sleep 2
    fi
fi

progress 10 "Formatting partitions..."

# Format partitions
if [ -n "$BOOT_PART" ]; then
    run_cmd mkfs.fat -F32 "$BOOT_PART"
fi
run_cmd mkfs.ext4 -F "$ROOT_PART"

progress 15 "Mounting partitions..."

# Mount partitions
run_cmd mount "$ROOT_PART" /mnt
if [ -n "$BOOT_PART" ]; then
    run_silent mkdir -p /mnt/boot
    run_cmd mount "$BOOT_PART" /mnt/boot
fi

progress 20 "Installing base system..."

# Install base packages
BASE_PACKAGES="base base-devel linux linux-firmware"
run_cmd pacstrap /mnt $BASE_PACKAGES

progress 40 "Configuring system..."

# Generate fstab
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would generate fstab"
else
    genfstab -U /mnt >> /mnt/etc/fstab
fi

# Configure locale
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would configure locale: $LANGUAGE"
else
    echo "en_US.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    if [ "$LANGUAGE" != "en_US" ]; then
        echo "${LANGUAGE}.UTF-8 UTF-8" >> /mnt/etc/locale.gen
    fi
    arch-chroot /mnt locale-gen
    echo "LANG=${LANGUAGE}.UTF-8" > /mnt/etc/locale.conf
fi

# Configure timezone
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would set timezone: $TIMEZONE"
else
    arch-chroot /mnt ln -sf /usr/share/zoneinfo/"$TIMEZONE" /etc/localtime
    arch-chroot /mnt hwclock --systohc
fi

# Configure keyboard
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would set keyboard: $KEYBOARD"
else
    echo "KEYMAP=$KEYBOARD" > /mnt/etc/vconsole.conf
fi

# Set hostname
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would set hostname: $HOSTNAME"
else
    echo "$HOSTNAME" > /mnt/etc/hostname
    cat > /mnt/etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   $HOSTNAME.localdomain $HOSTNAME
EOF
fi

progress 50 "Creating user account..."

# Create user
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would create user: $USERNAME"
else
    arch-chroot /mnt useradd -m -G wheel,audio,video,storage,optical -s /bin/bash "$USERNAME"
    echo "$USERNAME:$PASSWORD" | arch-chroot /mnt chpasswd
    echo "%wheel ALL=(ALL:ALL) ALL" >> /mnt/etc/sudoers.d/wheel
fi

progress 55 "Installing bootloader..."

# Install and configure bootloader
if [ "$BOOT_MODE" = "UEFI" ]; then
    run_cmd pacstrap /mnt grub efibootmgr
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would install GRUB (UEFI)"
    else
        arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=EndOS
    fi
else
    run_cmd pacstrap /mnt grub
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would install GRUB (BIOS) to $DISK"
    else
        arch-chroot /mnt grub-install --target=i386-pc "$DISK"
    fi
fi

# Generate GRUB config
if [ "$INSTALL_MODE" = "dualboot" ]; then
    run_cmd pacstrap /mnt os-prober
    if [ "$DRY_RUN" = false ]; then
        echo "GRUB_DISABLE_OS_PROBER=false" >> /mnt/etc/default/grub
    fi
fi
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would generate GRUB config"
else
    arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
fi

progress 60 "Installing desktop environment..."

# Install Hyprland and dots
run_cmd pacstrap /mnt hyprland kitty waybar wofi dolphin

# Copy dots-hyprland configuration
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would copy dots-hyprland configuration"
else
    mkdir -p /mnt/home/"$USERNAME"/.config
    cp -r /usr/share/dots-hyprland/* /mnt/home/"$USERNAME"/.config/
    arch-chroot /mnt chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/.config
    
    # Create wallpaper directory
    mkdir -p /mnt/home/"$USERNAME"/Pictures/Wallpapers
    cp /home/liveuser/Pictures/Wallpapers/* /mnt/home/"$USERNAME"/Pictures/Wallpapers/ 2>/dev/null || true
    arch-chroot /mnt chown -R "$USERNAME":"$USERNAME" /home/"$USERNAME"/Pictures
fi

progress 70 "Installing optional packages..."

# Install optional packages
if [ -n "$INSTALL_PACKAGES" ]; then
    run_cmd pacstrap /mnt $INSTALL_PACKAGES
fi

# Install custom packages
if [ -n "$CUSTOM_PACKAGES" ]; then
    run_cmd pacstrap /mnt $CUSTOM_PACKAGES
fi

progress 80 "Installing graphics drivers..."

# Install graphics drivers
if [ "$NEEDS_NVIDIA" = "true" ]; then
    run_cmd pacstrap /mnt nvidia nvidia-utils
fi

if [ "$NEEDS_AMD" = "true" ]; then
    run_cmd pacstrap /mnt mesa xf86-video-amdgpu vulkan-radeon
fi

# Install Intel drivers (always, for integrated graphics)
run_cmd pacstrap /mnt mesa intel-media-driver vulkan-intel

progress 85 "Configuring display manager..."

# Install and configure display manager (SDDM)
run_cmd pacstrap /mnt sddm

# Enable auto-login at system level
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would configure auto-login for $USERNAME"
else
    mkdir -p /mnt/etc/sddm.conf.d
    cat > /mnt/etc/sddm.conf.d/autologin.conf <<EOF
[Autologin]
User=$USERNAME
Session=hyprland
EOF
    # Enable SDDM
    arch-chroot /mnt systemctl enable sddm
fi

progress 90 "Configuring lock on boot..."

# Set lock on boot preference (user controls via config.json)
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would configure lock-on-boot setting"
else
    mkdir -p /mnt/home/"$USERNAME"/.config/illogical-impulse
    if [ ! -f /mnt/home/"$USERNAME"/.config/illogical-impulse/config.json ]; then
        echo '{"lockOnBoot": true}' > /mnt/home/"$USERNAME"/.config/illogical-impulse/config.json
        arch-chroot /mnt chown "$USERNAME":"$USERNAME" /home/"$USERNAME"/.config/illogical-impulse/config.json
    fi
fi

progress 95 "Enabling services..."

# Enable NetworkManager
run_cmd pacstrap /mnt networkmanager
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would enable NetworkManager"
else
    arch-chroot /mnt systemctl enable NetworkManager
fi

# Enable Bluetooth if needed
if lspci | grep -i bluetooth &>/dev/null; then
    run_cmd pacstrap /mnt bluez bluez-utils
    if [ "$DRY_RUN" = true ]; then
        echo "[DRY-RUN] Would enable Bluetooth"
    else
        arch-chroot /mnt systemctl enable bluetooth
    fi
fi

progress 98 "Cleaning up..."

# Unmount partitions
if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Would unmount /mnt"
else
    umount -R /mnt
fi

progress 100 "Installation complete!"

exit 0
