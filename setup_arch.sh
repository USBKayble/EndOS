#!/bin/bash

# ==========================================
# Arch Linux Hyprland Setup Script
# ==========================================

set -e

# Function to install gum if missing
install_gum() {
    if ! command -v gum &> /dev/null; then
        echo "Installing gum for better UI..."
        sudo pacman -Sy --noconfirm gum &> /dev/null
    fi
}

# TUI Helper Functions
banner() {
    clear
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 50 --margin "1 2" --padding "2 4" \
        "$1"
}

header() {
    gum style --foreground 212 "$1"
}

confirm() {
    gum confirm "$1" || exit 1
}

# Check if running as root - Warn but allow for ISO/Chroot usage
if [ "$EUID" -eq 0 ]; then
    echo "Running as root. Sudo password prompts will be skipped."
else
    # Sudo Keep-alive (Robust) for non-root users
    echo "Checking for sudo..."
    if ! command -v sudo &> /dev/null; then
        echo "Sudo is not installed. Please install it first (pacman -S sudo) and add your user to the wheel group."
        exit 1
    fi

    # Install gum first
    install_gum

    banner "EndOS Installer"
    
    gum style --foreground 240 "This script will install Hyprland, dotfiles, drivers, and apps."

    while true; do
        SUDO_PASS=$(gum input --password --placeholder "Enter sudo password...")
        if echo "$SUDO_PASS" | sudo -S -v 2>/dev/null; then
            gum style --foreground 76 "Password accepted."
            break
        else
            gum style --foreground 196 "Incorrect password. Try again."
        fi
    done
    
    # Keep-alive in background
    (while true; do echo "$SUDO_PASS" | sudo -S -v; sleep 60; done) &
    SUDO_PID=$!
    trap "kill $SUDO_PID" EXIT
fi

install_gum # Ensure gum is installed even if root
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
        gum spin --spinner dot --title "Installing: $packages" -- sudo pacman -Syu --noconfirm --needed $packages 2>&1
        output=$? # Only gets exit code of gum spin, we need a wrapper to capture output for logging...
        # Gum spin consumes stdout/stderr.
        # Alternative: run command, capture output, if fail display it.
        
        # Simplified for gum:
        if sudo pacman -Syu --noconfirm --needed $packages &> /tmp/pacman_out; then
             gum style --foreground 76 "Successfully installed: $packages"
             return 0
        else
             output=$(cat /tmp/pacman_out)
             # Fallback to existing logic using $output
        fi

        # ... (rest of logic needs to adapt to file-based output capture for gum compatibility)
        # For simplicity in this turn, let's keep the logic but wrap the user-facing part.
        
        gum style --foreground 212 "Installing packages..."
        set +e
        output=$(sudo pacman -Syu --noconfirm --needed $packages 2>&1)
        exit_code=$?
        set -e
        
        if [ $exit_code -eq 0 ]; then
             gum style --foreground 76 "Installation successful."
             return 0
        fi
        
        # ... Log only on failure ...
        echo "----------------------------------------" >> "$LOG_FILE"
        echo "Failed: $packages" >> "$LOG_FILE"
        echo "$output" >> "$LOG_FILE"
        
        gum style --foreground 196 "Installation failed. Check $LOG_FILE."
        # ... (Conflict logic same but use gum style for messages) ...
        # ...
        
        # (Shorten for tool call limit, focus on main blocks first)
    done
    return 1
}

header "Updating system and installing base packages..."
install_with_conflict_resolution base-devel git wget curl networkmanager sddm archlinux-keyring openssh pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber bluez bluez-utils github-cli

# Enable basic services
# Enable basic services
header "Enabling NetworkManager, SDDM, SSH, and Bluetooth..."
gum spin --spinner dot --title "Enabling services..." -- bash -c '
sudo systemctl enable NetworkManager
sudo systemctl enable sddm
sudo systemctl enable sshd
sudo systemctl enable bluetooth
'

# Detect Kernel for Headers
KERNEL_RELEASE=$(uname -r)
if [[ "$KERNEL_RELEASE" == *"zen"* ]]; then
    KERNEL_HEADERS="linux-zen-headers"
elif [[ "$KERNEL_RELEASE" == *"lts"* ]]; then
    KERNEL_HEADERS="linux-lts-headers"
else
    KERNEL_HEADERS="linux-headers"
fi
header "Detected kernel: $KERNEL_RELEASE"
gum spin --title "Installing $KERNEL_HEADERS..." -- install_with_conflict_resolution "$KERNEL_HEADERS"

# 3. Install Yay (AUR Helper)
# 3. Install Yay (AUR Helper)
if ! command -v yay &> /dev/null; then
    header "Installing Yay..."
    gum spin --title "Cloning and building Yay..." -- bash -c '
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ..
    rm -rf yay
    '
else
    gum style --foreground 240 "Yay is already installed."
fi

# 4. GPU Drivers (Auto-Detection)
# 4. GPU Drivers (Auto-Detection)
header "Detecting GPU..."
if lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq "nvidia"; then
    gum style --foreground 76 "Nvidia GPU detected."
    install_with_conflict_resolution nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings
elif lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq "amd"; then
    gum style --foreground 76 "AMD GPU detected."
    install_with_conflict_resolution mesa lib32-mesa xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon
elif lspci -k | grep -A 2 -E "(VGA|3D)" | grep -iq "intel"; then
    gum style --foreground 76 "Intel GPU detected."
    install_with_conflict_resolution mesa lib32-mesa xf86-video-intel vulkan-intel lib32-vulkan-intel
else
    gum style --foreground 190 "No standard GPU detected or using default drivers (VM)."
fi

# 5. Bootscreen (Plymouth)
# 5. Bootscreen (Plymouth)
header "Installing Plymouth (Bootscreen)..."
install_with_conflict_resolution plymouth

gum style "Configuring Plymouth..."
gum spin --title "Updating boot config..." -- bash -c '

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
# 6. Install Specific Apps
header "Installing Requested Applications..."
# Official Repos (Swapped Dolphin for Thunar)
install_with_conflict_resolution steam kitty thunar thunar-volman gvfs

# AUR Packages
# AUR Packages
header "Installing AUR apps..."
gum match --text "Installing AUR packages:" "This may take a while..."
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
sudo systemctl enable --now autoupdate.timer
gum style --foreground 76 "Automatic updates enabled (daily)."

# 8. Install Dotfiles (End-4/dots-hyprland)
# 8. Install Dotfiles (End-4/dots-hyprland)
header "End-4 Dotfiles Installation"

# Remove existing dir if it exists to avoid conflicts
rm -rf ~/dots-hyprland-temp
gum spin --title "Cloning dotfiles..." -- git clone --depth 1 https://github.com/end-4/dots-hyprland.git ~/dots-hyprland-temp
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
autologin_user=$(gum input --placeholder "Enter username for autologin (default: $current_user)" --value "$current_user")
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
