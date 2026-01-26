#!/usr/bin/env bash
# ISO Inspection and Verification Script
# This script mounts the ISO, inspects critical files and structure, then unmounts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT_DIR="${SCRIPT_DIR}/out"
MOUNT_DIR="/tmp/endos-iso-mount-$$"
REPORT_FILE="${SCRIPT_DIR}/iso-inspection-report-$(date +%Y%m%d-%H%M%S).txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_section() {
    echo -e "\n${BLUE}=== $1 ===${NC}" | tee -a "$REPORT_FILE"
}

log_success() {
    echo -e "${GREEN}✓ $1${NC}" | tee -a "$REPORT_FILE"
}

log_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" | tee -a "$REPORT_FILE"
}

log_error() {
    echo -e "${RED}✗ $1${NC}" | tee -a "$REPORT_FILE"
}

log_info() {
    echo "$1" | tee -a "$REPORT_FILE"
}

# Find the most recent ISO
log_section "Finding ISO File"
ISO_FILE=$(find "$OUT_DIR" -name "*.iso" -type f -printf '%T@ %p\n' | sort -rn | head -1 | cut -d' ' -f2-)

if [ -z "$ISO_FILE" ]; then
    log_error "No ISO file found in $OUT_DIR"
    exit 1
fi

ISO_NAME=$(basename "$ISO_FILE")
ISO_SIZE=$(du -h "$ISO_FILE" | cut -f1)
log_success "Found: $ISO_NAME"
log_info "Size: $ISO_SIZE"

# Check if size is under 6GB
ISO_SIZE_BYTES=$(stat -c%s "$ISO_FILE")
ISO_SIZE_GB=$(echo "scale=2; $ISO_SIZE_BYTES / 1024 / 1024 / 1024" | bc)
log_info "Size in GB: ${ISO_SIZE_GB}GB"

if (( $(echo "$ISO_SIZE_GB < 6" | bc -l) )); then
    log_success "ISO size is under 6GB target"
else
    log_warning "ISO size exceeds 6GB target"
fi

# Create mount point
log_section "Mounting ISO"
sudo mkdir -p "$MOUNT_DIR"
sudo mount -o loop "$ISO_FILE" "$MOUNT_DIR"
log_success "Mounted at $MOUNT_DIR"

# Trap to ensure unmount on exit
trap "sudo umount '$MOUNT_DIR' 2>/dev/null; sudo rmdir '$MOUNT_DIR' 2>/dev/null" EXIT

# Extract squashfs
log_section "Extracting SquashFS"
SQUASHFS_FILE=$(find "$MOUNT_DIR" -name "airootfs.sfs" -o -name "*.sfs" | head -1)

if [ -z "$SQUASHFS_FILE" ]; then
    log_error "Could not find squashfs file"
    exit 1
fi

SQUASH_DIR="/tmp/endos-squash-$$"
sudo mkdir -p "$SQUASH_DIR"
trap "sudo umount '$MOUNT_DIR' 2>/dev/null; sudo rmdir '$MOUNT_DIR' 2>/dev/null; sudo rm -rf '$SQUASH_DIR' 2>/dev/null" EXIT

log_info "Extracting $(basename "$SQUASHFS_FILE")..."
sudo unsquashfs -d "$SQUASH_DIR" "$SQUASHFS_FILE" >/dev/null 2>&1
log_success "Extracted to $SQUASH_DIR"

# Now inspect the filesystem
log_section "Verifying Critical Files and Directories"

# Function to check if file/dir exists
check_exists() {
    local path="$1"
    local description="$2"
    local full_path="${SQUASH_DIR}${path}"
    
    if [ -e "$full_path" ]; then
        log_success "$description: $path"
        return 0
    else
        log_error "$description: $path NOT FOUND"
        return 1
    fi
}

# Function to check file content
check_content() {
    local path="$1"
    local pattern="$2"
    local description="$3"
    local full_path="${SQUASH_DIR}${path}"
    
    if [ -f "$full_path" ]; then
        if sudo grep -q "$pattern" "$full_path"; then
            log_success "$description"
            return 0
        else
            log_warning "$description - Pattern not found: $pattern"
            return 1
        fi
    else
        log_error "$description - File not found: $path"
        return 1
    fi
}

# Check quickshell venv
log_section "Quickshell Virtual Environment"
check_exists "/usr/share/quickshell/venv" "System venv directory"
check_exists "/usr/share/quickshell/venv/bin/activate" "Venv activate script"
check_exists "/usr/share/quickshell/venv/bin/python" "Venv Python binary"

if [ -x "${SQUASH_DIR}/usr/share/quickshell/venv/bin/python" ]; then
    PYTHON_VERSION=$(sudo chroot "$SQUASH_DIR" /usr/share/quickshell/venv/bin/python --version 2>&1)
    log_info "Python version: $PYTHON_VERSION"
    if echo "$PYTHON_VERSION" | grep -q "3.14"; then
        log_success "Python 3.14 confirmed"
    else
        log_warning "Python version is not 3.14"
    fi
fi

# List installed packages in venv
log_info "\nInstalled Python packages in system venv:"
if [ -x "${SQUASH_DIR}/usr/share/quickshell/venv/bin/pip" ]; then
    sudo chroot "$SQUASH_DIR" /usr/share/quickshell/venv/bin/pip list 2>&1 | head -20 | tee -a "$REPORT_FILE"
else
    log_warning "pip not found in venv"
fi

# Check dotfiles structure
log_section "Dotfiles Structure"
check_exists "/etc/skel/dots-hyprland" "Skel dots-hyprland repository"
check_exists "/home/liveuser/dots-hyprland" "Liveuser dots-hyprland repository"
check_exists "/etc/skel/.config" "Skel .config directory"
check_exists "/home/liveuser/.config" "Liveuser .config directory"
check_exists "/etc/skel/.local" "Skel .local directory"
check_exists "/home/liveuser/.local" "Liveuser .local directory"

# Check specific config directories
log_section "Specific Config Directories"
check_exists "/etc/skel/.config/hypr" "Skel Hyprland config"
check_exists "/etc/skel/.config/quickshell" "Skel Quickshell config"
check_exists "/etc/skel/.config/fish" "Skel Fish config"
check_exists "/etc/skel/.config/kitty" "Skel Kitty config"
check_exists "/home/liveuser/.config/hypr" "Liveuser Hyprland config"
check_exists "/home/liveuser/.config/quickshell" "Liveuser Quickshell config"

# Check env.conf patches
log_section "Environment Configuration"
check_content "/etc/skel/.config/hypr/hyprland/env.conf" "ILLOGICAL_IMPULSE_VIRTUAL_ENV.*quickshell/venv" "Skel env.conf has system venv path"
check_content "/home/liveuser/.config/hypr/hyprland/env.conf" "ILLOGICAL_IMPULSE_VIRTUAL_ENV.*quickshell/venv" "Liveuser env.conf has system venv path"

log_info "\nSkel env.conf content:"
sudo grep "ILLOGICAL_IMPULSE_VIRTUAL_ENV" "${SQUASH_DIR}/etc/skel/.config/hypr/hyprland/env.conf" 2>/dev/null | tee -a "$REPORT_FILE" || log_warning "Could not read skel env.conf"

log_info "\nLiveuser env.conf content:"
sudo grep "ILLOGICAL_IMPULSE_VIRTUAL_ENV" "${SQUASH_DIR}/home/liveuser/.config/hypr/hyprland/env.conf" 2>/dev/null | tee -a "$REPORT_FILE" || log_warning "Could not read liveuser env.conf"

# Check system configuration
log_section "System Configuration"
check_exists "/etc/modules-load.d/i2c-dev.conf" "i2c-dev module loading config"
check_content "/etc/modules-load.d/i2c-dev.conf" "i2c-dev" "i2c-dev module configured"

# Check for i2c group
log_info "\nChecking for i2c group in /etc/group:"
if sudo grep -q "^i2c:" "${SQUASH_DIR}/etc/group"; then
    log_success "i2c group exists"
else
    log_warning "i2c group not found"
fi

# Check systemd services
log_section "Systemd Services"
check_exists "/usr/lib/systemd/system/bluetooth.service" "Bluetooth service unit"

# Check if bluetooth is enabled
if [ -e "${SQUASH_DIR}/etc/systemd/system/multi-user.target.wants/bluetooth.service" ] || \
   [ -e "${SQUASH_DIR}/etc/systemd/system/bluetooth.target.wants/bluetooth.service" ]; then
    log_success "Bluetooth service is enabled"
else
    log_warning "Bluetooth service may not be enabled"
fi

# Check ydotool
if [ -e "${SQUASH_DIR}/usr/lib/systemd/user/ydotool.service" ]; then
    log_success "ydotool user service exists"
elif [ -e "${SQUASH_DIR}/usr/lib/systemd/system/ydotool.service" ]; then
    log_info "ydotool system service exists (user link may be created at runtime)"
else
    log_warning "ydotool service not found"
fi

# Check scripts
log_section "Custom Scripts"
check_exists "/usr/local/bin/post-install-dots.sh" "Post-install script"
check_exists "/usr/local/bin/qs" "Quickshell wrapper script"

if [ -f "${SQUASH_DIR}/usr/local/bin/qs" ]; then
    log_info "\nQuickshell wrapper content:"
    sudo cat "${SQUASH_DIR}/usr/local/bin/qs" | tee -a "$REPORT_FILE"
fi

# Check shell profile
log_section "Shell Configuration"
check_exists "/etc/skel/.zprofile" "Skel .zprofile"
check_exists "/home/liveuser/.zprofile" "Liveuser .zprofile"

if [ -f "${SQUASH_DIR}/home/liveuser/.zprofile" ]; then
    log_info "\nLiveuser .zprofile content:"
    sudo cat "${SQUASH_DIR}/home/liveuser/.zprofile" | tee -a "$REPORT_FILE"
fi

# Check firstrun marker
log_section "Firstrun Markers"
check_exists "/etc/skel/.config/illogical-impulse/installed_true" "Skel firstrun marker"
check_exists "/home/liveuser/.config/illogical-impulse/installed_true" "Liveuser firstrun marker"

# Space analysis
log_section "Space Analysis"
log_info "\nTop 20 largest directories:"
sudo du -h -d 2 "$SQUASH_DIR" 2>/dev/null | sort -rh | head -20 | tee -a "$REPORT_FILE"

# Check for common space wasters
log_info "\nChecking for potential space wasters:"
DOC_SIZE=$(sudo du -sh "${SQUASH_DIR}/usr/share/doc" 2>/dev/null | cut -f1)
MAN_SIZE=$(sudo du -sh "${SQUASH_DIR}/usr/share/man" 2>/dev/null | cut -f1)
LOCALE_SIZE=$(sudo du -sh "${SQUASH_DIR}/usr/share/locale" 2>/dev/null | cut -f1)
CACHE_SIZE=$(sudo du -sh "${SQUASH_DIR}/var/cache" 2>/dev/null | cut -f1)

log_info "Documentation: ${DOC_SIZE:-cleaned}"
log_info "Man pages: ${MAN_SIZE:-cleaned}"
log_info "Locales: ${LOCALE_SIZE:-unknown}"
log_info "Cache: ${CACHE_SIZE:-unknown}"

# Package count
log_section "Package Information"
if [ -d "${SQUASH_DIR}/var/lib/pacman/local" ]; then
    PKG_COUNT=$(sudo find "${SQUASH_DIR}/var/lib/pacman/local" -mindepth 1 -maxdepth 1 -type d | wc -l)
    log_info "Installed packages: $PKG_COUNT"
fi

# Final summary
log_section "Summary"
log_info "ISO File: $ISO_NAME"
log_info "ISO Size: $ISO_SIZE ($ISO_SIZE_GB GB)"
log_info "Report saved to: $REPORT_FILE"

echo -e "\n${GREEN}Inspection complete!${NC}"
echo "Full report: $REPORT_FILE"
