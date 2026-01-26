#!/usr/bin/env bash
# Quick test script to verify installer components

echo "=== EndOS Installer Component Test ==="
echo ""

# Test 1: Check if launcher script exists and is executable
echo -n "✓ Launcher script exists... "
if [ -x "/home/kaleb/Projects/EndOS/iso/airootfs/usr/local/bin/endos-installer" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
fi

# Test 2: Check if main QML file exists
echo -n "✓ Main QML file exists... "
if [ -f "/home/kaleb/Projects/EndOS/iso/airootfs/usr/share/endos-installer/installer.qml" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
fi

# Test 3: Check all page files
echo -n "✓ All page files exist... "
PAGES=(WelcomePage LanguagePage NetworkPage DiskPage UserPage HostnamePage PackagePage ReviewPage ProgressPage CompletionPage)
ALL_PAGES_EXIST=true
for page in "${PAGES[@]}"; do
    if [ ! -f "/home/kaleb/Projects/EndOS/iso/airootfs/usr/share/endos-installer/pages/${page}.qml" ]; then
        echo "✗ FAIL (missing ${page}.qml)"
        ALL_PAGES_EXIST=false
        break
    fi
done
if [ "$ALL_PAGES_EXIST" = true ]; then
    echo "✓ PASS (${#PAGES[@]} pages)"
fi

# Test 4: Check all scripts exist and are executable
echo -n "✓ All scripts executable... "
SCRIPTS=(detect-hardware detect-disks detect-os install write-config)
ALL_SCRIPTS_EXIST=true
for script in "${SCRIPTS[@]}"; do
    if [ ! -x "/home/kaleb/Projects/EndOS/iso/airootfs/usr/share/endos-installer/scripts/${script}.sh" ]; then
        echo "✗ FAIL (missing or not executable: ${script}.sh)"
        ALL_SCRIPTS_EXIST=false
        break
    fi
done
if [ "$ALL_SCRIPTS_EXIST" = true ]; then
    echo "✓ PASS (${#SCRIPTS[@]} scripts)"
fi

# Test 5: Check desktop file
echo -n "✓ Desktop file exists... "
if [ -f "/home/kaleb/Projects/EndOS/iso/airootfs/usr/share/applications/endos-installer.desktop" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
fi

# Test 6: Check autostart script
echo -n "✓ Autostart script exists... "
if [ -x "/home/kaleb/Projects/EndOS/iso/airootfs/usr/local/bin/autostart-installer" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
fi

# Test 7: Check Hyprland autostart config
echo -n "✓ Hyprland autostart configured... "
if grep -q "autostart-installer" "/home/kaleb/Projects/EndOS/iso/airootfs/etc/skel/.config/hypr/custom/execs.conf"; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
fi

# Test 8: Run detection scripts
echo ""
echo "=== Testing Detection Scripts ==="

echo -n "✓ Hardware detection... "
if /home/kaleb/Projects/EndOS/iso/airootfs/usr/share/endos-installer/scripts/detect-hardware.sh >/dev/null 2>&1; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
fi

echo -n "✓ Disk detection... "
if /home/kaleb/Projects/EndOS/iso/airootfs/usr/share/endos-installer/scripts/detect-disks.sh >/dev/null 2>&1; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
fi

# Test 9: Verify wallpaper directory structure
echo ""
echo "=== Testing Wallpaper Fix ==="
echo -n "✓ Live user wallpaper directory... "
if [ -d "/home/kaleb/Projects/EndOS/iso/airootfs/home/liveuser/Pictures/Wallpapers" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
fi

echo -n "✓ Skel wallpaper directory... "
if [ -d "/home/kaleb/Projects/EndOS/iso/airootfs/etc/skel/Pictures/Wallpapers" ]; then
    echo "✓ PASS"
else
    echo "✗ FAIL"
fi

echo ""
echo "=== Component Test Complete ==="
echo ""
echo "To test the installer UI locally (dry-run mode):"
echo "  cd /home/kaleb/Projects/EndOS/iso/airootfs/usr/share/endos-installer"
echo "  qs -p installer.qml"
echo ""
echo "Or run full installer with:"
echo "  /home/kaleb/Projects/EndOS/iso/airootfs/usr/local/bin/endos-installer --dry-run"
