#!/bin/bash

# ==========================================
# Arch Linux Hyprland Setup Script
# ==========================================

set -e

# Function to install gum if missing
install_gum() {
    if ! command -v gum &> /dev/null; then
        echo "Installing gum for better UI..."
        # We assume pacman is available and configured (setup script usually run on Arch)
        # Use --noconfirm to avoid blocking
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

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo "Running as root."
    SUDO=""
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
    SUDO="sudo"
fi

install_gum # Ensure gum is installed even if root

echo "Enabling multilib repository..."
if ! grep -q "^\[multilib\]" /etc/pacman.conf; then
    $SUDO bash -c 'echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf'
    $SUDO pacman -Sy
else
    echo "Multilib seems to be enabled already."
fi

# 2. System Update & Base Packages
echo "Updating mirrors with Reflector..."
$SUDO pacman -Syu --noconfirm --needed reflector
$SUDO cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
$SUDO reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist

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
        gum spin --spinner dot --title "Installing: $packages" -- $SUDO pacman -Syu --noconfirm --needed $packages 2>&1
        output=$? # Capture exit code from gum spin (which captures the command's exit code)

        # Re-run command to capture output if needed? No, that's inefficient.
        # Let's assume we capture it properly if we need to log.
        # For this script's purposes, we'll execute directly for output capture first.
        
        # Proper way to capture output AND use spinner:
        # Create a temp file
        temp_out=$(mktemp)
        
        # Start the spinner in background, waiting for a PID file or similar?
        # Simpler: Use gum spin to run the command and redirect output to file
        gum spin --spinner dot --title "Installing packages..." -- bash -c "$SUDO pacman -Syu --noconfirm --needed $packages &> $temp_out"
        exit_code=$?
        output=$(cat $temp_out)
        rm $temp_out
        
        if [ $exit_code -eq 0 ]; then
             gum style --foreground 76 "Installation successful."
             return 0
        fi
        
        # Only log to file on failure
        echo "----------------------------------------" >> "$LOG_FILE"
        echo "Failed command: $SUDO pacman -Syu --noconfirm --needed $packages" >> "$LOG_FILE"
        echo "$output" >> "$LOG_FILE"
        
        gum style --foreground 196 "Installation failed. Check $LOG_FILE."
        
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
                $SUDO pacman -Rdd --noconfirm "$candidate"
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
    return 1
}

header "Updating system and installing base packages..."
install_with_conflict_resolution base-devel git wget curl networkmanager sddm archlinux-keyring openssh pipewire pipewire-alsa pipewire-pulse pipewire-jack wireplumber bluez bluez-utils github-cli

# Enable basic services
header "Enabling NetworkManager, SDDM, SSH, and Bluetooth..."
gum spin --spinner dot --title "Enabling services..." -- bash -c "
$SUDO systemctl enable NetworkManager
$SUDO systemctl enable sddm
$SUDO systemctl enable sshd
$SUDO systemctl enable bluetooth
"

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
header "Installing Yay..."
if ! command -v yay &> /dev/null; then
    # Special handling for Root: makepkg cannot run as root
    if [ "$EUID" -eq 0 ]; then
        echo "Detected root. Creating temporary 'builder' user for AUR..."
        useradd -m builder
        echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
        
        gum spin --title "Building Yay as 'builder' user..." -- bash -c "
        su builder -c 'git clone https://aur.archlinux.org/yay.git /tmp/yay && cd /tmp/yay && makepkg -si --noconfirm'
        "
        
        # Cleanup
        userdel -r builder
    else
        gum spin --title "Building Yay..." -- bash -c "
        git clone https://aur.archlinux.org/yay.git
        cd yay
        makepkg -si --noconfirm
        cd ..
        rm -rf yay
        "
    fi
else
    gum style --foreground 240 "Yay is already installed."
fi

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
header "Installing Plymouth (Bootscreen)..."
install_with_conflict_resolution plymouth

gum style "Configuring Plymouth..."
gum spin --title "Updating boot config..." -- bash -c "

# Plymouth Configuration Block
{
    # Backup
    [ ! -f /etc/mkinitcpio.conf.bak ] && $SUDO cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.bak
    [ -f /etc/default/grub ] && [ ! -f /etc/default/grub.bak ] && $SUDO cp /etc/default/grub /etc/default/grub.bak
    
    # Edit mkinitcpio: add 'plymouth' to HOOKS
    if ! grep -q 'plymouth' /etc/mkinitcpio.conf; then
        echo 'Adding plymouth hook to mkinitcpio...'
        $SUDO sed -i 's/udev/udev plymouth/' /etc/mkinitcpio.conf
    else
        echo 'Plymouth hook already present in mkinitcpio.'
    fi
     
    echo \"Setting default theme to 'spinner'...\"
    $SUDO plymouth-set-default-theme -R spinner

    # Detect Bootloader
    if [ -d '/sys/firmware/efi' ]; then
        echo 'EFI system detected.'
    fi

    if command -v grub-mkconfig &> /dev/null && [ -f '/boot/grub/grub.cfg' ]; then
        echo 'GRUB detected.'
        if ! grep -q 'splash quiet' /etc/default/grub; then
             $SUDO sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=\"/GRUB_CMDLINE_LINUX_DEFAULT=\"splash quiet /' /etc/default/grub
        else
             echo 'GRUB splash/quiet parameters already present.'
        fi
        echo 'Regenerating GRUB config...'
        $SUDO grub-mkconfig -o /boot/grub/grub.cfg || exit 1 # pause_on_error cannot be called inside subshell easily?

    elif command -v bootctl &> /dev/null && bootctl status &> /dev/null; then
        echo 'systemd-boot detected.'
        echo 'Attempting to add splash quiet to systemd-boot entries...'
        for entry in /boot/loader/entries/*.conf; do
            if grep -q 'options' \"\$entry\" && ! grep -q 'splash quiet' \"\$entry\"; then
                $SUDO sed -i '/^options/ s/$/ splash quiet/' \"\$entry\"
                echo \"Updated \$entry\"
            fi
        done
    else
        echo 'Could not detect GRUB or systemd-boot configuration.'
    fi

    echo 'Regenerating initramfs...'
    $SUDO mkinitcpio -P || exit 1
}
"

# 6. Install Specific Apps
header "Installing Requested Applications..."
# Official Repos (Swapped Dolphin for Thunar)
# Official Repos (Swapped Dolphin for Thunar)
# Added dependencies for end-4 dots: aylurs-gtk-shell hypridle hyprlock swww python-pywal imagemagick cliphist wl-clipboard grim slurp swappy
install_with_conflict_resolution steam kitty thunar thunar-volman gvfs hypridle hyprlock python-pywal imagemagick cliphist wl-clipboard grim slurp swappy network-manager-applet btop fuzzel

# AUR Packages
header "Installing AUR apps..."
gum match --text "Installing AUR packages:" "This may take a while..."
yay -S --noconfirm spotify spicetify-cli millennium-bin vesktop zen-browser-bin aylurs-gtk-shell swww

# Spicetify Permissions Fix
echo "Applying Spicetify permissions fix..."
$SUDO chmod a+wr /opt/spotify
$SUDO chmod a+wr /opt/spotify/Apps -R

# 7. Automatic Updates (Pacman only)
echo "Setting up automatic updates (Systemd timer for Pacman)..."
$SUDO bash -c 'cat > /etc/systemd/system/autoupdate.service <<EOF
[Unit]
Description=Automatic System Update

[Service]
Type=oneshot
ExecStart=/usr/bin/pacman -Syu --noconfirm
EOF'

$SUDO bash -c 'cat > /etc/systemd/system/autoupdate.timer <<EOF
[Unit]
Description=Run automatic system update daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF'

$SUDO systemctl enable --now autoupdate.timer
gum style --foreground 76 "Automatic updates enabled (daily)."

# 8. Install Dotfiles (End-4/dots-hyprland)
header "End-4 Dotfiles Installation"

# Detect Target User (if running as root in chroot)
TARGET_USER=$(whoami)
if [ "$EUID" -eq 0 ]; then
    # Try to detect the first regular user in /home
    DETECTED_USER=$(ls /home | head -n 1)
    if [ -n "$DETECTED_USER" ]; then
        TARGET_USER="$DETECTED_USER"
    fi
    gum style --foreground 240 "Running as root. Detected target user: $TARGET_USER"
fi

# Confirm user
TARGET_USER=$(gum input --placeholder "Install dotfiles for user" --value "$TARGET_USER")
TARGET_HOME=$(eval echo "~$TARGET_USER")

gum style "Installing dotfiles for $TARGET_USER ($TARGET_HOME)..."

# Remove existing dir if it exists to avoid conflicts
rm -rf $TARGET_HOME/dots-hyprland-temp

if [ -d "$OFFLINE_DOTS" ]; then
    gum style --foreground 76 "Offline source detected at $OFFLINE_DOTS. Installing from ISO..."
    
    # Handle subdir if present
    DETECTED_SRC="$OFFLINE_DOTS"
    if [ -d "$OFFLINE_DOTS/dots" ]; then
         DETECTED_SRC="$OFFLINE_DOTS/dots"
    fi
    
    # Smart Copy Logic
    mkdir -p "$TARGET_HOME/.config"
    mkdir -p "$TARGET_HOME/dots-hyprland-temp" # Still needed? Maybe just direct copy is better if we trust the structure.
    
    # Actually, setup_arch.sh usually RUNS the setup script.
    # The user provided setup script does 'install-files'.
    # If we want to skip the setup script and manually install (fast/offline):
    
    echo "Installing configs directly..."
    if [ -d "$DETECTED_SRC/.config" ]; then
        cp -a "$DETECTED_SRC/." "$TARGET_HOME/"
    elif [ -d "$DETECTED_SRC/hypr" ]; then
        cp -a "$DETECTED_SRC/." "$TARGET_HOME/.config/"
    else
         cp -a "$DETECTED_SRC/." "$TARGET_HOME/.config/"
    fi
    
    # Ensure ownership
    chown -R $TARGET_USER:$TARGET_USER "$TARGET_HOME"
    
else
    # Online Clone
    gum spin --title "Cloning dotfiles from GitHub..." -- sudo -u $TARGET_USER git clone --depth 1 https://github.com/end-4/dots-hyprland.git $TARGET_HOME/dots-hyprland-temp
fi

# Skip the "setup install" runner if we did offline install?
# The original script ran ./setup install.
# If we did online clone, we have the repo in temps.
# If we did offline copy, we essentially INSTALLED strictly the files.
# We might skip the ./setup execution for offline mode to be safe/fast/no-internet.

if [ ! -d "$OFFLINE_DOTS" ]; then
    echo "Running dotfiles installer (Online Mode)..."
    cd $TARGET_HOME/dots-hyprland-temp
    set +e 
    su $TARGET_USER -c "./setup install"
    install_exit_code=$?
    set -e
    rm -rf $TARGET_HOME/dots-hyprland-temp
else
    echo "Offline install complete. Skipped upstream installer script."
    install_exit_code=0
fi

# 9. Configure SDDM Autologin
echo "==========================================
Configuring SDDM Autologin (Bypass Lock Screen)..."

# Ensure Hyprland session file exists (just in case)
if [ ! -f "/usr/share/wayland-sessions/hyprland.desktop" ]; then
    echo "Creating Hyprland session file..."
    $SUDO mkdir -p /usr/share/wayland-sessions
    $SUDO bash -c 'cat > /usr/share/wayland-sessions/hyprland.desktop <<EOF
[Desktop Entry]
Name=Hyprland
Comment=Hyprland Session
Exec=Hyprland
Type=Application
EOF'
fi

autologin_user=$(gum input --placeholder "Enter username for autologin" --value "$TARGET_USER")

echo "Setting up autologin for user: $autologin_user"
if [ ! -d "/etc/sddm.conf.d" ]; then
    $SUDO mkdir -p /etc/sddm.conf.d
fi

# Force write the autologin config
$SUDO bash -c "cat > /etc/sddm.conf.d/autologin.conf <<EOF
[Autologin]
User=$autologin_user
Session=hyprland.desktop
EOF"

# Ensure correct permissions
$SUDO chmod 644 /etc/sddm.conf.d/autologin.conf
echo "SDDM Autologin configured."

echo "==========================================
Setup Complete!"
echo "Note: Millennium for Steam may require you to toggle the 'Millennium' option inside Steam settings."
echo "Note: For Spicetify, run 'spicetify backup apply' once you've logged into Spotify."
echo "Please reboot your system."
