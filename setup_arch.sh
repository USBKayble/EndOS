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

# Sudo Keep-alive
# Ask for sudo password upfront
echo "Checking for sudo..."
if ! command -v sudo &> /dev/null; then
    echo "Sudo is not installed. Please install it first (pacman -S sudo) and add your user to the wheel group."
    exit 1
fi

echo "Please enter your password to authorize the installation..."
sudo -v

# Keep-alive: update existing sudo time stamp until the script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
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
sudo pacman -Syu --noconfirm --needed base-devel git wget curl networkmanager sddm archlinux-keyring openssh pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber bluez bluez-utils

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
