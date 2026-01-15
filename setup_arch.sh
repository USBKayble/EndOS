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

LOG_FILE="./setup_error.log"

# Function to log messages (Console only)
log_msg() {
    echo "$1"
}

# Function to log errors (Console + File)
log_error() {
    echo "ERROR: $1" >&2
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] - $1" >> "$LOG_FILE"
}

# Function to pause on error
pause_on_error() {
    log_error "$1"
    read -p "Press Enter to acknowledge and continue (or Ctrl+C to abort)..."
}

# Function to ask user to report errors to GitHub
report_issues() {
    if [ -f "$LOG_FILE" ]; then
        echo ""
        echo "=========================================="
        echo "Errors were recorded during installation."
        echo "=========================================="
        read -p "Would you like to report these issues to GitHub now? (y/n) " report_choice
        if [[ "$report_choice" =~ ^[Yy]$ ]]; then
            echo "Checking query tool..."
            
            # Try GitHub CLI first
            if command -v gh &> /dev/null && gh auth status &>/dev/null; then
                 echo "Submitting issue to GitHub (Authenticated)..."
                 gh issue create --title "Installation Error Report $(date +%F)" --body "Automated error report. See attached logs." --repo USBKayble/EndOS
                 echo "Please paste the contents of $LOG_FILE into the issue comments."
            else
                 # Fallback to anonymous upload (0x0.st)
                 echo "GitHub CLI not authenticated. Uploading log anonymously to 0x0.st..."
                 if command -v curl &> /dev/null; then
                     log_url=$(curl -F "file=@$LOG_FILE" https://0x0.st)
                     echo "=========================================="
                     echo "Log uploaded successfully!"
                     echo "Please share this URL with the developer:"
                     echo "$log_url"
                     echo "=========================================="
                     echo "(You can paste this URL into a simplified issue report)"
                 else
                     echo "Error: 'curl' is not installed. Cannot upload log."
                     echo "Please manually copy the content of $LOG_FILE."
                 fi
                 
                 echo "Please manually report issues at: https://github.com/USBKayble/EndOS/issues"
            fi
        fi
    fi
}
trap report_issues EXIT

# Function to handle package installation with dynamic conflict resolution and smart checks
install_with_conflict_resolution() {
    local requested_packages=("$@")
    local packages_to_install=()
    
    # Smart Check: Filter out already installed packages
    for pkg in "${requested_packages[@]}"; do
        if pacman -Qq "$pkg" &> /dev/null; then
            echo "Skipping $pkg (already installed)"
        else
            packages_to_install+=("$pkg")
        fi
    done
    
    if [ ${#packages_to_install[@]} -eq 0 ]; then
        echo "All packages are already installed. Skipping."
        return 0
    fi

    local packages="${packages_to_install[*]}"
    local max_retries=5
    local retry_count=0

    while [ $retry_count -lt $max_retries ]; do
        echo "Attempting installation of: $packages (Try $((retry_count+1))/$max_retries)..."
        
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
        
        # Only log to file on failure
        echo "----------------------------------------" >> "$LOG_FILE"
        echo "Failed command: sudo pacman -Syu --noconfirm --needed $packages" >> "$LOG_FILE"
        echo "$output" >> "$LOG_FILE"
        
        echo "$output"
        log_error "Installation failed via pacman. Check $LOG_FILE for details."
        
        # Check for specific conflict pattern ":: pkgA and pkgB are in conflict"
        conflict_line=$(echo "$output" | grep "are in conflict" | head -n 1)
        
        if [ -n "$conflict_line" ]; then
            echo "Conflict detected: $conflict_line"
            log_msg "Conflict detected: $conflict_line"
            
            # Extract package names (Assuming format ":: pkgA and pkgB are in conflict")
            pkgA=$(echo "$conflict_line" | awk '{print $2}')
            pkgB=$(echo "$conflict_line" | awk '{print $4}')
            
            # Determine which package to remove (the one currently installed)
            candidate=""
            if pacman -Qq "$pkgA" &>/dev/null && pacman -Qq "$pkgB" &>/dev/null; then
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
                     pause_on_error "Failed to remove $candidate. Manual intervention required."
                     return 1
                fi
                retry_count=$((retry_count+1))
                continue
            else
                pause_on_error "Could not identify installed conflicting package. Manual intervention required."
                return 1
            fi
        else
            pause_on_error "Installation failed with non-conflict error (e.g., download failed). See $LOG_FILE."
            return 1
        fi
    done
    
    pause_on_error "Max retries reached. Installation failed."
    return 1
}

echo "Updating system and installing base-devel, git, wget, curl, NetworkManager, sddm, openssh, pipewire types..."
install_with_conflict_resolution base-devel git wget curl networkmanager sddm archlinux-keyring openssh pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber bluez bluez-utils github-cli

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
install_with_conflict_resolution "$KERNEL_HEADERS"

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
    install_with_conflict_resolution nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
elif lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq "amd"; then
    echo "AMD GPU detected. Installing AMD drivers..."
    install_with_conflict_resolution mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon
elif lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq "intel"; then
    echo "Intel GPU detected. Installing Intel drivers..."
    install_with_conflict_resolution mesa lib32-mesa xf86-video-intel vulkan-intel lib32-vulkan-intel
else
    echo "No standard GPU detected or using default drivers (VM)."
fi

# 5. Bootscreen (Plymouth)
echo "Installing Plymouth (Bootscreen)..."
install_with_conflict_resolution plymouth

echo "To enable Plymouth, we need to modify mkinitcpio and bootloader config."
echo "Attempting automatic configuration..."

# Plymouth Configuration Block
{
    # Backup
    [ ! -f /etc/mkinitcpio.conf.bak ] && sudo cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
    [ -f /etc/default/grub ] && [ ! -f /etc/default/grub.bak ] && sudo cp /etc/default/grub /etc/default/grub.bak
    
    # Edit mkinitcpio: add 'plymouth' to HOOKS
    if ! grep -q "plymouth" /etc/mkinitcpio.conf; then
        echo "Adding plymouth hook to mkinitcpio..."
        sudo sed -i 's/udev/udev plymouth/' /etc/mkinitcpio.conf
    else
        echo "Plymouth hook already present in mkinitcpio."
    fi
     
    echo "Setting default theme to 'spinner'..."
    sudo plymouth-set-default-theme -R spinner

    # Detect Bootloader
    if [ -d "/sys/firmware/efi" ]; then
        echo "EFI system detected."
    fi

    if command -v grub-mkconfig &> /dev/null && [ -f "/boot/grub/grub.cfg" ]; then
        echo "GRUB detected."
        if ! grep -q "splash quiet" /etc/default/grub; then
             sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="/GRUB_CMDLINE_LINUX_DEFAULT="splash quiet /' /etc/default/grub
        else
             echo "GRUB splash/quiet parameters already present."
        fi
        echo "Regenerating GRUB config..."
        sudo grub-mkconfig -o /boot/grub/grub.cfg || pause_on_error "Failed to generate GRUB config."

    elif command -v bootctl &> /dev/null && bootctl status &> /dev/null; then
        echo "systemd-boot detected."
        echo "Attempting to add 'splash quiet' to systemd-boot entries..."
        for entry in /boot/loader/entries/*.conf; do
            if grep -q "options" "$entry" && ! grep -q "splash quiet" "$entry"; then
                sudo sed -i '/^options/ s/$/ splash quiet/' "$entry"
                echo "Updated $entry"
            fi
        done
    else
        echo "Could not detect GRUB or systemd-boot configuration."
        echo "You may need to add 'splash quiet' to your kernel parameters manually."
    fi

    echo "Regenerating initramfs..."
    sudo mkinitcpio -P || pause_on_error "Failed to regenerate initramfs."
}

# 6. Install Specific Apps
echo "Installing requested applications..."
# Official Repos (Swapped Dolphin for Thunar)
install_with_conflict_resolution steam kitty thunar thunar-volman gvfs

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
    if [ $install_exit_code -eq 143 ]; then
         echo "Dotfiles installer exited with 143 (SIGTERM). This is expected if Hyprland is not running."
         echo "Assuming success and proceeding..."
    else
        echo "=========================================="
        echo "The dotfiles installer exited with an unexpected error code ($install_exit_code)."
        echo "Please review the output above for details."
        echo "If this was a critical failure, you may want to abort and investigate."
        echo "=========================================="
        read -t 15 -p "Continue with SDDM/Autologin setup? (y/N) " continue_choice
        continue_choice=${continue_choice:-N} # Default to No for safety
        
        if [[ ! "$continue_choice" =~ ^[Yy]$ ]]; then
            echo "Aborting setup. Please report this issue."
            exit $install_exit_code
        fi
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
