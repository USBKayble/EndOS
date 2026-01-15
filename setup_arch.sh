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
echo "Updating system and installing base-devel, git, wget, curl, NetworkManager, sddm..."
sudo pacman -Syu --noconfirm --needed base-devel git wget curl networkmanager sddm archlinux-keyring
sudo systemctl enable NetworkManager
sudo systemctl enable sddm

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

# 4. GPU Drivers
echo "==========================================
Select your GPU vendor for driver installation:
1) Nvidia
2) AMD
3) Intel
4) Skip / Virtual Machine
read -p "Enter choice [1-4]: " gpu_choice

case $gpu_choice in
    1)
        echo "Installing Nvidia drivers..."
        sudo pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
        ;;
    2)
        echo "Installing AMD drivers..."
        sudo pacman -S --noconfirm --needed mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon
        ;;
    3)
        echo "Installing Intel drivers..."
        sudo pacman -S --noconfirm --needed mesa lib32-mesa xf86-video-intel vulkan-intel lib32-vulkan-intel
        ;;
    *)
        echo "Skipping driver installation."
        ;;
esac

# 5. Bootscreen (Plymouth)
echo "Installing Plymouth (Bootscreen)..."
yay -S --noconfirm plymouth

echo "To enable Plymouth, we need to modify mkinitcpio and grub."
read -p "Do you want to attempt automatic configuration of Plymouth? (y/n) " plymouth_config

if [[ "$plymouth_config" =~ ^[Yy]$ ]]; then
    # Backup
    sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
    sudo cp /etc/default/grub /etc/default/grub.bak
    
    # Edit mkinitcpio: add 'plymouth' to HOOKS
    # We look for HOOKS=(... udev ... ) and insert plymouth after udev
    sudo sed -i 's/udev/udev plymouth/' /etc/mkinitcpio.conf
    
    # Edit GRUB: add 'splash quiet'
    if ! grep -q "splash quiet" /etc/default/grub; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="splash quiet /' /etc/default/grub
    fi
    
    echo "Setting default theme to 'spinner'..."
    sudo plymouth-set-default-theme -R spinner
    
    echo "Regenerating initramfs and grub config..."
    sudo mkinitcpio -P
    if command -v grub-mkconfig &> /dev/null; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    else
        echo "GRUB not found, skipping grub-mkconfig. Please configure your bootloader manually."
    fi
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
    echo "==========================================
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
