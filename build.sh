#!/usr/bin/env bash
set -eo pipefail

# Get script directory for portable paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Configuration
REPO_URL="https://github.com/end-4/dots-hyprland.git"
REPO_DIR="dots-hyprland"
ISO_DIR="iso"
WORK_DIR="work"
OUT_DIR="out"

LOG_FILE="build.log"
# Redirect everything to log file AND stdout
exec > >(tee "$LOG_FILE") 2>&1

echo "=== Starting EndOS Build Process ==="

# Official Package Name Changes (replaces name in the list)
declare -A OFFICIAL_ALIASES=(
    ["qt6-avif-image-plugin"]="qt6-imageformats"
    ["ttf-material-symbols-variable-git"]="ttf-material-symbols-variable"
    ["ttf-twemoji"]="ttf-twemoji-color"
)

# Build-only Aliases (Maps package name to AUR Base name for building only)
declare -A BUILD_ALIASES=(
    ["otf-space-grotesk"]="38c3-styles"
)

# Step 1: Cleanup
echo "--> Cleaning up previous build artifacts..."
sudo rm -rf "$WORK_DIR"
rm -rf "$REPO_DIR"

# Step 2: Clone dots-hyprland
echo "--> Cloning dots-hyprland..."
git clone "$REPO_URL" "$REPO_DIR"

# Step 3: Extract & Populate Packages/Requirements
echo "--> Extracting packages and requirements from dots-hyprland..."

TEMP_PKG_LIST=$(mktemp)
TEMP_REQ_LIST=$(mktemp)

# Use a bash subshell to source the official installation logic and extract package names
bash -c "
  cd '$REPO_DIR'
  showfun() { :; }
  v() { :; }
  x() { :; }
  try() { :; }
  source_if_exists() { :; }
  export ask=false
  export SKIP_SYSUPDATE=true
  export REPO_ROOT=\$(pwd)
  if [ -f 'sdata/dist-arch/install-deps.sh' ]; then
    source 'sdata/dist-arch/install-deps.sh' 2>/dev/null || true
    for dir in \"\${metapkgs[@]}\"; do
      if [ -f \"\$dir/PKGBUILD\" ]; then
        (
          depends=()
          makedepends=()
          source \"\$dir/PKGBUILD\" 2>/dev/null
          for dep in \"\${depends[@]}\"; do echo \"\$dep\"; done
          for dep in \"\${makedepends[@]}\"; do echo \"\$dep\"; done
        )
      fi
    done
    echo 'plasma-browser-integration'
  fi
" | sed 's/["'\'']//g' | grep -a -E '^[a-z0-9@._+-]+$' | grep -avE "^(v|x|try|showfun|source_if_exists)$" | sort -u >> "$TEMP_PKG_LIST"

# Apply Official Aliases to the extracted list
for pkg in "${!OFFICIAL_ALIASES[@]}"; do
    sed -i "s/^$pkg$/${OFFICIAL_ALIASES[$pkg]}/" "$TEMP_PKG_LIST"
done

# Strategy for Python requirements
find "$REPO_DIR" -name "requirements.txt" -exec cat {} + >> "$TEMP_REQ_LIST" 2>/dev/null || true

# Rebuild packages.x86_64 from source files + dynamic list
PKG_LIST_FILE="${ISO_DIR}/packages.x86_64"
BASE_PKG_FILE="${ISO_DIR}/base.packages.x86_64"
USER_PKG_FILE="${ISO_DIR}/user.packages.x86_64"

echo "--> Rebuilding $PKG_LIST_FILE..."
TEMP_FINAL_LIST=$(mktemp)

# Combine: Base + User + Dynamic (strip CRLF to handle Windows line endings)
cat "$BASE_PKG_FILE" 2>/dev/null | tr -d '\r' >> "$TEMP_FINAL_LIST"
cat "$USER_PKG_FILE" 2>/dev/null | tr -d '\r' >> "$TEMP_FINAL_LIST"
cat "$TEMP_PKG_LIST" 2>/dev/null | tr -d '\r' >> "$TEMP_FINAL_LIST"

# Sort, Unique, and final sanity filter
sort -u "$TEMP_FINAL_LIST" | grep -a -vE "^\s*#|^\s*$" | grep -a -E '^[a-z0-9@._+-]+$' > "${TEMP_FINAL_LIST}.clean"

# Check for changes
PKG_LIST_CHANGED=true
if [ -f "$PKG_LIST_FILE" ] && cmp -s "$PKG_LIST_FILE" "${TEMP_FINAL_LIST}.clean"; then
    echo "    Package list unchanged."
    PKG_LIST_CHANGED=false
    rm "${TEMP_FINAL_LIST}.clean"
else
    echo "    Package list updated."
    mv "${TEMP_FINAL_LIST}.clean" "$PKG_LIST_FILE"
    PKG_LIST_CHANGED=true
fi
rm "$TEMP_FINAL_LIST"

# Update iso/requirements.txt
echo "--> Updating requirements.txt..."
REQ_FILE="${ISO_DIR}/requirements.txt"
cat "$REQ_FILE" "$TEMP_REQ_LIST" 2>/dev/null | grep -vE "^\s*#|^\s*$" | sort -u > "${REQ_FILE}.tmp"
mv "${REQ_FILE}.tmp" "$REQ_FILE"

# Step 4: Distribute Dotfiles
echo "--> Distributing dotfiles (incremental)..."
TARGET_SKEL="${ISO_DIR}/airootfs/etc/skel/dots-hyprland"
TARGET_ROOT="${ISO_DIR}/airootfs/root/dots-hyprland"
TARGET_LIVE="${ISO_DIR}/airootfs/home/liveuser/dots-hyprland"

mkdir -p "$TARGET_SKEL" "$TARGET_ROOT" "$TARGET_LIVE"
# Use rsync to only copy changed files
rsync -a --delete "$REPO_DIR/" "$TARGET_SKEL/"
rsync -a --delete "$REPO_DIR/" "$TARGET_ROOT/"
rsync -a --delete "$REPO_DIR/" "$TARGET_LIVE/"

# Step 4b: Bake dotfile configs at build time (for faster first boot)
echo "--> Baking dotfile configs into ISO..."
SKEL_CONFIG="${ISO_DIR}/airootfs/etc/skel/.config"
SKEL_LOCAL="${ISO_DIR}/airootfs/etc/skel/.local"
LIVE_CONFIG="${ISO_DIR}/airootfs/home/liveuser/.config"
LIVE_LOCAL="${ISO_DIR}/airootfs/home/liveuser/.local"

mkdir -p "$SKEL_CONFIG" "$SKEL_LOCAL" "$LIVE_CONFIG" "$LIVE_LOCAL"

# Copy config files from dots-hyprland to skel and liveuser
if [ -d "$REPO_DIR/dots/.config" ]; then
    echo "    Copying .config files..."
    rsync -a "$REPO_DIR/dots/.config/" "$SKEL_CONFIG/"
    rsync -a "$REPO_DIR/dots/.config/" "$LIVE_CONFIG/"
fi

if [ -d "$REPO_DIR/dots/.local" ]; then
    echo "    Copying .local files..."
    rsync -a "$REPO_DIR/dots/.local/" "$SKEL_LOCAL/"
    rsync -a "$REPO_DIR/dots/.local/" "$LIVE_LOCAL/"
fi

# Create the firstrun flag to prevent post-install from running full setup
echo "    Creating firstrun marker..."
LIVE_DOTS_FLAG="${ISO_DIR}/airootfs/home/liveuser/.config/illogical-impulse/installed_true"
SKEL_DOTS_FLAG="${ISO_DIR}/airootfs/etc/skel/.config/illogical-impulse/installed_true"
mkdir -p "$(dirname "$LIVE_DOTS_FLAG")" "$(dirname "$SKEL_DOTS_FLAG")"
touch "$LIVE_DOTS_FLAG" "$SKEL_DOTS_FLAG"

# Step 5: Local Repo
echo "--> Managing local repository..."
HOST_REPO_DIR="${SCRIPT_DIR}/local_repo"
LOCAL_REPO_DIR="${ISO_DIR}/airootfs/var/local_repo/x86_64"
mkdir -p "$HOST_REPO_DIR"
mkdir -p "$LOCAL_REPO_DIR"

# Pre-emptive strike: Sync host repositories to ISO pacman.conf
# This ensures mkarchiso can see extra repos if the user has them enabled.
# Note: chaotic-aur removed - user prefers building AUR packages directly
echo "    Syncing host repository configurations..."
for repo in "extra-testing" "core-testing"; do
    if grep -q "^\[$repo\]" /etc/pacman.conf; then
        if ! grep -q "^\[$repo\]" "$ISO_DIR/pacman.conf"; then
            echo "      - Adding $repo to ISO config..."
            # Extract the block from host config
            printf "\n" >> "$ISO_DIR/pacman.conf"
            sed -n "/^\[$repo\]/,/^$/p" /etc/pacman.conf >> "$ISO_DIR/pacman.conf"
        fi
    fi
done

# Verification Step: Check if local packages are corrupt or missing
echo "    Verifying local package integrity..."
VERIFY_FAILED=false
for pkg_file in "$HOST_REPO_DIR"/*.pkg.tar.zst; do
    [ -e "$pkg_file" ] || continue
    # pacman -Qp verifies the package archive is valid and readable
    if ! pacman -Qp "$pkg_file" >/dev/null 2>&1; then
        echo "      - CORRUPT: $(basename "$pkg_file"). Removing."
        rm "$pkg_file"
        VERIFY_FAILED=true
    fi
done

# Check if any packages from our list are missing entirely from the local cache
# (This catches cases where a build failed or was interrupted)
for pkg_name in $(grep -vE "^\s*#|^\s*$" "$PKG_LIST_FILE"); do
    # Search for a file starting with the package name and having a version suffix
    # We use a more flexible search for the version (can start with v or digit)
    if ! ls "$HOST_REPO_DIR"/"$pkg_name"-[v0-9]*.pkg.tar.zst >/dev/null 2>&1 && \
       ! ls "$HOST_REPO_DIR"/"$pkg_name"-[a-z0-9]*.pkg.tar.zst >/dev/null 2>&1; then
        # Check if it might be provided by a different file name (e.g. from an alias)
        # We also check if it exists in system repos - if not, and not in local, it's missing.
        if ! pacman -Si "$pkg_name" >/dev/null 2>&1; then
             # If it's not in system repos, it MUST be in local repo
             echo "      - MISSING: $pkg_name (needs rebuild/download)."
             VERIFY_FAILED=true
             break
        fi
    fi
done

if [ "$VERIFY_FAILED" = true ]; then
    echo "    Verification issues detected. Forcing update."
    PKG_LIST_CHANGED=true
fi

if [ "$PKG_LIST_CHANGED" = true ] || [ -z "$(ls -A "$HOST_REPO_DIR" 2>/dev/null | grep '\.pkg\.tar\.zst$')" ]; then
    echo "    Updating local package cache..."
    TEMP_DB_PATH=$(mktemp -d)
    chmod 777 "$TEMP_DB_PATH"
    echo "    Syncing with system repositories..."
    # Use ISO's pacman.conf to detect AUR packages correctly (not host's which may have Chaotic AUR)
    sudo pacman -Sy --config "$ISO_DIR/pacman.conf" --dbpath "$TEMP_DB_PATH"
    
    # Track which packages fail to download from official repos (potential AUR packages)
    echo "    Downloading official packages..."
    # We use a temporary log to catch missing packages
    PACMAN_LOG=$(mktemp)
    sudo pacman -Syw --config "$ISO_DIR/pacman.conf" --cachedir "$HOST_REPO_DIR" --noconfirm --dbpath "$TEMP_DB_PATH" - < "$PKG_LIST_FILE" 2> "$PACMAN_LOG" || true
    
    # Identify AUR packages
    AUR_PKGS=$(grep "error: target not found:" "$PACMAN_LOG" | awk '{print $NF}' | sort -u)
    rm "$PACMAN_LOG"
    
    if [ -n "$AUR_PKGS" ]; then
        echo "    Detected AUR packages. Attempting to build..."
        # Ensure base-devel and common build dependencies are present
        sudo pacman -S --needed --noconfirm base-devel fontforge python-fonttools
        
        # Start a sudo keepalive in the background so we don't timeout during long builds
        echo "    Starting sudo keepalive for long builds..."
        (while true; do sudo -v; sleep 60; done) &
        SUDO_KEEPALIVE_PID=$!
        trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null" EXIT
        
        BUILD_DIR=$(mktemp -d)
        chmod 777 "$BUILD_DIR"
        
        # Find the non-root user for yay/makepkg
        if [ "$(whoami)" != "root" ]; then
            REAL_USER="$(whoami)"
        else
            REAL_USER=${SUDO_USER:-$(logname 2>/dev/null || echo "kaleb")}
        fi
        
        # Ensure the user owns the repo dir so yay can write to it
        chown -R "$REAL_USER" "$HOST_REPO_DIR"

        for pkg in $AUR_PKGS; do
            # Check if we already have it built in the repo (handle any version format)
            if ls "$HOST_REPO_DIR"/"$pkg"-*.pkg.tar.zst >/dev/null 2>&1; then
                echo "      - $pkg already built. Skipping."
                continue
            fi
            
            echo "      - Building $pkg from AUR using yay..."
            (
                # Use a temporary directory for the yay build process
                BUILD_SUBDIR=$(mktemp -d)
                chmod 777 "$BUILD_SUBDIR"
                
                # We use PKGDEST to force yay/makepkg to put the output in our repo
                # and we use --aur to ensure we hit the AUR repo
                export PKGDEST="$HOST_REPO_DIR"
                
                # If the package is in BUILD_ALIASES, use the base name for the build
                BUILD_PKG="${BUILD_ALIASES[$pkg]:-$pkg}"
                
                # Clone the AUR repository
                cd "$BUILD_SUBDIR"
                git clone "https://aur.archlinux.org/${BUILD_PKG}.git" "$BUILD_PKG" 2>/dev/null || {
                    echo "        ERROR: Could not clone $BUILD_PKG from AUR"
                    exit 1
                }
                
                cd "$BUILD_PKG"
                
                # Build with -s to sync dependencies automatically, -f to force rebuild
                sudo -u "$REAL_USER" PKGDEST="$HOST_REPO_DIR" makepkg -sf --noconfirm
                
                # Strict verification: Check if any new package file appeared in PKGDEST
                if [ -z "$(find "$HOST_REPO_DIR" -maxdepth 1 -name "*.pkg.tar.zst" -mmin -2)" ]; then
                    echo "        ERROR: Build completed but no new package file found for $pkg (built as $BUILD_PKG)."
                    exit 1
                fi
            ) || {
                echo "        ERROR: Failed to build $pkg."
                exit 1
            }
        done
        sudo rm -rf "$BUILD_DIR"
    fi
    sudo rm -rf "$TEMP_DB_PATH"
else
    echo "    Using existing package cache."
fi

# Sync packages to airootfs and generate database
echo "    Syncing local packages to ISO..."
if ls "$HOST_REPO_DIR"/*.pkg.tar.zst >/dev/null 2>&1; then
    cp "$HOST_REPO_DIR"/*.pkg.tar.zst "$LOCAL_REPO_DIR/" 2>/dev/null || true
    # Generate database in the airootfs location
    repo-add -n -R "$LOCAL_REPO_DIR/local_repo.db.tar.gz" "$LOCAL_REPO_DIR"/*.pkg.tar.zst >/dev/null
    echo "    $(ls "$LOCAL_REPO_DIR"/*.pkg.tar.zst 2>/dev/null | wc -l) packages synced with database"
fi

# Clean up temp db if it was created
[ -d "${TEMP_DB_PATH:-}" ] && sudo rm -rf "$TEMP_DB_PATH"

echo "--> Caching Python wheels..."
WHEELS_DIR="${ISO_DIR}/airootfs/var/cache/wheels"
PIP_CACHE="${SCRIPT_DIR}/.pip_cache"
mkdir -p "$WHEELS_DIR" "$PIP_CACHE"

# Build wheels locally (includes downloading and building from source if needed)
# This ensures all packages are available as .whl files for offline installation
echo "    Building/downloading wheels with pip..."
if ! pip wheel --cache-dir "$PIP_CACHE" -r "$REQ_FILE" -w "$WHEELS_DIR"; then
    echo "ERROR: Failed to build Python wheels. Aborting."
    exit 1
fi

# Verify all required packages have been downloaded
echo "    Verifying Python wheels..."
WHEELS_FAILED=false
while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
    # Extract package name (before ==, >=, etc.)
    pkg_base=$(echo "$line" | sed -E 's/([a-zA-Z0-9_-]+).*/\1/' | tr '[:upper:]' '[:lower:]')
    # Try both underscore and hyphen versions (pip naming is inconsistent)
    pkg_underscore=$(echo "$pkg_base" | tr '-' '_')
    pkg_hyphen=$(echo "$pkg_base" | tr '_' '-')
    # Check if any file matches either format
    if ! ls "$WHEELS_DIR"/${pkg_underscore}* >/dev/null 2>&1 && \
       ! ls "$WHEELS_DIR"/*${pkg_underscore}* >/dev/null 2>&1 && \
       ! ls "$WHEELS_DIR"/${pkg_hyphen}* >/dev/null 2>&1 && \
       ! ls "$WHEELS_DIR"/*${pkg_hyphen}* >/dev/null 2>&1; then
        echo "      - MISSING: $pkg_base"
        WHEELS_FAILED=true
    fi
done < "$REQ_FILE"

if [ "$WHEELS_FAILED" = true ]; then
    echo "ERROR: Some Python wheels are missing. Aborting."
    exit 1
fi
echo "    All Python wheels verified."

# Step 7: Post-Install Config
echo "--> Configuring post-install hooks..."

# Function to configure .zprofile (more reliable for auto-login than .zlogin)
configure_zprofile() {
    local target_file="$1"
    local target_dir=$(dirname "$target_file")
    
    mkdir -p "$target_dir"
    
    # Check if we already added our logic
    if ! grep -q "dots-hyprland-installed" "$target_file" 2>/dev/null; then
        echo "" >> "$target_file"
        echo "# Automated EndOS Install Logic" >> "$target_file"
        echo "if [ ! -f ~/.config/dots-hyprland-installed ]; then" >> "$target_file"
        echo "    /usr/local/bin/post-install-dots.sh" >> "$target_file"
        echo "    mkdir -p ~/.config" >> "$target_file"
        echo "    touch ~/.config/dots-hyprland-installed" >> "$target_file"
        echo "fi" >> "$target_file"
        echo "" >> "$target_file"
        echo "exec start-hyprland" >> "$target_file"
    fi
}

configure_zprofile "${ISO_DIR}/airootfs/home/liveuser/.zprofile"
configure_zprofile "${ISO_DIR}/airootfs/etc/skel/.zprofile"

# Step 8: Build
echo "--> Building ISO..."
# Ensure output dir exists
mkdir -p "$OUT_DIR"

# Pre-populate pacman cache AND regenerate repo database
echo "    Setting up local packages for build..."
if ls "$HOST_REPO_DIR"/*.pkg.tar.zst >/dev/null 2>&1; then
    # Regenerate database to ensure it matches current packages
    echo "    Regenerating local repo database..."
    rm -f "$HOST_REPO_DIR"/local_repo.db* "$HOST_REPO_DIR"/local_repo.files* 2>/dev/null || true
    repo-add -n -R "$HOST_REPO_DIR/local_repo.db.tar.gz" "$HOST_REPO_DIR"/*.pkg.tar.zst >/dev/null
    
    # Also copy packages to system cache as backup
    sudo mkdir -p /var/cache/pacman/pkg
    sudo cp "$HOST_REPO_DIR"/*.pkg.tar.zst /var/cache/pacman/pkg/ 2>/dev/null || true
    echo "    $(ls "$HOST_REPO_DIR"/*.pkg.tar.zst 2>/dev/null | wc -l) packages ready"
fi

sudo mkarchiso -v -w "$WORK_DIR" -o "$OUT_DIR" "$ISO_DIR"

echo "=== Build Complete ==="
