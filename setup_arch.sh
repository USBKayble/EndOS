#!/bin/bash

# ==========================================
# Arch Linux Hyprland Setup Script
# ==========================================

set -e

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Please do not run this script as root."
    echo "Run it as a normal user with sudo privileges."
    exit 1
fi

echo "Welcome to the Arch Linux Hyprland Setup Script."
echo "This script will install Hyprland, dotfiles, drivers, and various apps."
echo "Ensure you are running this on a fresh Arch Linux install with internet access."
read -p "Press Enter to continue or Ctrl+C to abort..."

# Sudo Keep-alive (Robust)
# Ask for password once, then keep sudo alive indefinitely
echo "Checking for sudo..."
if ! command -v sudo &> /dev/null; then
    echo "Sudo is not installed. Please install it first (pacman -S sudo) and add your user to the wheel group."
    exit 1
fi

while true; do
    read -s -p "Please enter your sudo password: " USER_PASS
    echo
    if echo "$USER_PASS" | sudo -S -v 2>/dev/null; then
        echo "Password accepted."
        break
    else
        echo "Incorrect password. Please try again."
    fi
done

# Keep-alive: update existing sudo time stamp using the captured password
# This ensures it never times out even if the script takes a long time
while true; do 
    echo "$USER_PASS" | sudo -S -v 2>/dev/null
    sleep 60
    kill -0 "$$" || exit
done &
KEEP_ALIVE_PID=$!
trap "kill $KEEP_ALIVE_PID" EXIT

# 1. Enable Multilib (needed for Steam)
echo "Enabling multilib repository..."
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    sudo bash -c 'echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf'
    sudo pacman -Sy
else
    echo "Multilib seems to be enabled already."
fi

# 2. System Update & Base Packages
echo "Updating mirrors with Reflector..."
sudo pacman -Syu --noconfirm --needed reflector
sudo cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

echo "Updating system and installing base-devel, git, wget, curl, NetworkManager, sddm, openssh, pipewire types..."

# Function to handle package installation with dynamic conflict resolution
install_with_conflict_resolution() {
    local packages="$*"
    local max_retries=5
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        echo "Attempting installation (Try $((retry_count+1))/$max_retries)..."
        
        # Run pacman and capture both stdout and stderr
        set +e
        output=$(sudo pacman -Syu --noconfirm --needed $packages 2>&1)
        exit_code=$?
        set -e
        
        if [ $exit_code -eq 0 ]; then
            echo "$output"
            echo "Installation successful."
            return 0
        fi
        
        echo "$output"
        
        # Check for specific conflict pattern ":: pkgA and pkgB are in conflict"
        conflict_line=$(echo "$output" | grep "are in conflict" | head -n 1)
        
        if [ -n "$conflict_line" ]; then
            echo "Conflict detected: $conflict_line"
            # Extract package names (Assuming format ":: pkgA and pkgB are in conflict")
            # We use awk to grab the 2nd and 4th words (adjusting for ":: ")
            pkgA=$(echo "$conflict_line" | awk '{print $2}')
            pkgB=$(echo "$conflict_line" | awk '{print $4}')
            
            # Determine which package to remove (the one currently installed)
            candidate=""
            if pacman -Qq "$pkgA" &>/dev/null && pacman -Qq "$pkgB" &>/dev/null; then
                 # Both installed? This is rare for a conflict during install unless replacing.
                 # We prefer to keep the one in our requested list, but logic is tricky.
                 # Let's guess pkgB is the blocker if pkgA is the new one 'pipewire-jack'.
                 # Actually, usually the one NOT in $packages is the target.
                 # Simple approach: remove the one that matches the installed check.
                 candidate="$pkgB" 
            elif pacman -Qq "$pkgA" &>/dev/null; then
                 candidate="$pkgA"
            elif pacman -Qq "$pkgB" &>/dev/null; then
                 candidate="$pkgB"
            fi
            
            if [ -n "$candidate" ]; then
                echo "Attempting to resolve conflict by removing existing package: $candidate..."
                set +e
                sudo pacman -Rdd --noconfirm "$candidate"
                rm_exit=$?
                set -e
                if [ $rm_exit -ne 0 ]; then
                     echo "Failed to remove $candidate. Manual intervention required."
                     return 1
                fi
                retry_count=$((retry_count+1))
                continue
            else
                echo "Could not identify installed conflicting package. Manual intervention required."
                return 1
            fi
        else
            echo "Installation failed with non-conflict error."
            return 1
        fi
    done
    
    echo "Max retries reached. Installation failed."
    return 1
}

echo "Updating system and installing base-devel, git, wget, curl, NetworkManager, sddm, openssh, pipewire types..."
install_with_conflict_resolution base-devel git wget curl networkmanager sddm archlinux-keyring openssh pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber bluez bluez-utils

# Enable basic services
echo "Enabling NetworkManager, SDDM, SSH, and Bluetooth..."
sudo systemctl enable NetworkManager
sudo systemctl enable sddm
sudo systemctl enable sshd
sudo systemctl enable bluetooth

# Detect Kernel for Headers (Needed for Nvidia DKMS)
KERNEL_RELEASE=$(uname -r)
if [[ "$KERNEL_RELEASE" == *"zen"* ]]; then
    KERNEL_HEADERS="linux-zen-headers"
elif [[ "$KERNEL_RELEASE" == *"lts"* ]]; then
    KERNEL_HEADERS="linux-lts-headers"
else
    KERNEL_HEADERS="linux-headers"
fi
echo "Detected kernel: $KERNEL_RELEASE. Installing $KERNEL_HEADERS..."
sudo pacman -S --noconfirm --needed "$KERNEL_HEADERS"

# 3. Install Yay (AUR Helper)
if ! command -v yay &> /dev/null; then
    echo "Installing Yay..."
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
else
    echo "Yay is already installed."
fi

# 4. GPU Drivers (Auto-Detection)
echo "Detecting GPU..."
if lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq "nvidia"; then
    echo "Nvidia GPU detected. Installing Nvidia drivers..."
    sudo pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
elif lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq "amd"; then
    echo "AMD GPU detected. Installing AMD drivers..."
    sudo pacman -S --noconfirm --needed mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon
elif lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq "intel"; then
    echo "Intel GPU detected. Installing Intel drivers..."
    sudo pacman -S --noconfirm --needed mesa lib32-mesa xf86-video-intel vulkan-intel lib32-vulkan-intel
else
    echo "No standard GPU detected or using default drivers (VM)."
fi

# 5. Bootscreen (Plymouth)
echo "Installing Plymouth (Bootscreen)..."
yay -S --noconfirm plymouth

echo "To enable Plymouth, we need to modify mkinitcpio and bootloader config."
read -p "Do you want to attempt automatic configuration of Plymouth? (y/n) " plymouth_config

if [[ "$plymouth_config" =~ ^[Yy]$ ]]; then
    # Backup
    sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
    
    # Edit mkinitcpio: add 'plymouth' to HOOKS
    # We look for HOOKS=(... udev ... ) and insert plymouth after udev
    if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        echo "Adding plymouth hook to mkinitcpio..."
        sudo sed -i 's/udev/udev plymouth/' /etc/mkinitcpio.conf
    fi
     
    echo "Setting default theme to 'spinner'..."
    sudo plymouth-set-default-theme -R spinner

    # Detect Bootloader
    if [ -d "/sys/firmware/efi" ]; then
        echo "EFI system detected."
    fi

    if command -v grub-mkconfig &> /dev/null && [ -f "/boot/grub/grub.cfg" ]; then
        echo "GRUB detected."
        sudo cp /etc/default/grub /etc/default/grub.bak
        if ! grep -q "splash quiet" /etc/default/grub; then
             sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="splash quiet /' /etc/default/grub
        fi
        echo "Regenerating GRUB config..."
        sudo grub-mkconfig -o /boot/grub/grub.cfg

    elif command -v bootctl &> /dev/null && bootctl status &> /dev/null; then
        echo "systemd-boot detected."
        # This is trickier as config is per-entry. 
        # We'll try to find the standard arch entry and append options.
        # usually in /boot/loader/entries/*.conf
        echo "Attempting to add 'splash quiet' to systemd-boot entries..."
        for entry in /boot/loader/entries/*.conf; do
            if grep -q "options" "$entry" && ! grep -q "splash quiet" "$entry"; then
                sudo sed -i '/^options/ s/$/ splash quiet/' "$entry"
                echo "Updated $entry"
            fi
        done
    else
        echo "Could not detect GRUB or systemd-boot configuration. Please configure boot arguments manually."
    fi

    echo "Regenerating initramfs..."
    sudo mkinitcpio -P
else
    echo "Skipping automatic Plymouth configuration."
fi

# 6. Install Specific Apps
echo "Installing requested applications..."
# Official Repos
sudo pacman -S --noconfirm --needed steam kitty dolphin

# AUR Packages
echo "Installing AUR apps (this may take a while)..."
yay -S --noconfirm spotify spicetify-cli millennium-bin vesktop zen-browser-bin

# Spicetify Permissions Fix
echo "Applying Spicetify permissions fix..."
sudo chmod a+wr /opt/spotify
sudo chmod a+wr /opt/spotify/Apps -R

# 7. Automatic Updates (Pacman only)
echo "Setting up automatic updates (Systemd timer for Pacman)..."
sudo bash -c 'cat > /etc/systemd/system/autoupdate.service <<EOF
[Unit]
Description=Automatic System Update

[Service]
Type=oneshot
ExecStart=/usr/bin/pacman -Syu --noconfirm
EOF'

sudo bash -c 'cat > /etc/systemd/system/autoupdate.timer <<EOF
[Unit]
Description=Run automatic system update daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF'

sudo systemctl enable --now autoupdate.timer
echo "Automatic updates enabled (daily)."

# 8. Install Dotfiles (End-4/dots-hyprland)
echo "==========================================
Starting End-4 Dotfiles Installation...
Cloning repository manually for reliability..."

# Remove existing dir if it exists to avoid conflicts
rm -rf ~/dots-hyprland-temp
git clone --depth 1 https://github.com/end-4/dots-hyprland.git ~/dots-hyprland-temp
cd ~/dots-hyprland-temp

echo "Running dotfiles installer..."
set +e 
./setup install
install_exit_code=$?
set -e

if [ $install_exit_code -ne 0 ]; then
    echo "==========================================
The dotfiles installer exited with an error code ($install_exit_code)."
    echo "This is frequently caused by 'HYPRLAND_INSTANCE_SIGNATURE not set' because Hyprland isn't running yet."
    echo "If you saw that error, it is safe to ignore."
    echo "=========================================="
    read -t 10 -p "Continue with SDDM/Autologin setup? (Y/n) " continue_choice
    continue_choice=${continue_choice:-Y} # Default to Yes
    
    if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
        echo "Aborting setup."
        exit $install_exit_code
    fi
fi

cd ..
rm -rf ~/dots-hyprland-temp

# 9. Configure SDDM Autologin
echo "==========================================
Configuring SDDM Autologin (Bypass Lock Screen)..."

# Ensure Hyprland session file exists (just in case)
if [ ! -f "/usr/share/wayland-sessions/hyprland.desktop" ]; then
    echo "Creating Hyprland session file..."
    sudo mkdir -p /usr/share/wayland-sessions
    sudo bash -c 'cat > /usr/share/wayland-sessions/hyprland.desktop <<EOF
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session
Exec=Hyprland
Type=Application
EOF'
fi

current_user=$(whoami)
read -p "Enter username for autologin (default: $current_user): " autologin_user
autologin_user=${autologin_user:-$current_user}

echo "Setting up autologin for user: $autologin_user"
if [ ! -d "/etc/sddm.conf.d" ]; then
    sudo mkdir -p /etc/sddm.conf.d
fi

# Force write the autologin config
sudo bash -c "cat > /etc/sddm.conf.d/autologin.conf <<EOF
[Autologin]
User=$autologin_user
Session=hyprland.desktop
EOF"

# Ensure correct permissions
sudo chmod 644 /etc/sddm.conf.d/autologin.conf
echo "SDDM Autologin configured."

echo "==========================================
Setup Complete!"
echo "Note: Millennium for Steam may require you to toggle the 'Millennium' option inside Steam settings."
echo "Note: For Spicetify, run 'spicetify backup apply' once you've logged into Spotify."
echo "Please reboot your system."
