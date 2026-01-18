#!/bin/bash
set -e

# build.sh
# Main build script for EndOS ISO

echo "=== Step 0: Cloning dots-hyprland repository ==="
if [[ -d "dots-hyprland" ]]; then
    echo "dots-hyprland directory already exists, removing..."
    rm -rf dots-hyprland
fi
git clone https://github.com/end-4/dots-hyprland.git dots-hyprland

echo "=== Copying dots-hyprland to ISO airootfs ==="
rm -rf iso/airootfs/home/liveuser/dots-hyprland
cp -r dots-hyprland iso/airootfs/home/liveuser/dots-hyprland

rm -rf iso/airootfs/root/dots-hyprland
cp -r dots-hyprland iso/airootfs/root/dots-hyprland

mkdir -p iso/airootfs/etc/skel
rm -rf iso/airootfs/etc/skel/dots-hyprland
cp -r dots-hyprland iso/airootfs/etc/skel/dots-hyprland

echo "=== Step 1: Extracting Dependencies from Dots ==="
./extract_dots_packages.sh

echo "=== Step 2: Downloading/Building Wheels ==="
./download_wheels.sh

echo "=== Step 3: Creating Local Repository ==="
./create_local_repo.sh

echo "=== Step 4: Building ISO with mkarchiso ==="

sudo mkarchiso -v -r -w work -o out iso
