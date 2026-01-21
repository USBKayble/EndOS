#!/bin/bash
# EndOS Quickshell Diagnostic Script
# Collects comprehensive diagnostic information and uploads to pastebin
# Note: We don't use 'set -e' because we expect many checks to fail during debugging

OUTPUT_FILE="/tmp/endos-debug-$(date +%Y%m%d-%H%M%S).txt"

# Function to add section to output
add_section() {
    echo "" | tee -a "$OUTPUT_FILE"
    echo "==========================================" | tee -a "$OUTPUT_FILE"
    echo "$1" | tee -a "$OUTPUT_FILE"
    echo "==========================================" | tee -a "$OUTPUT_FILE"
}

# Start diagnostic
echo "EndOS Quickshell Diagnostic Report" > "$OUTPUT_FILE"
echo "Generated: $(date)" >> "$OUTPUT_FILE"
echo "Hostname: $(hostname)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Note: Hotfix logic removed per user request. Diagnostics only.

add_section "1. USER INFO"
{
    echo "User: $(whoami)"
    echo "TTY: $(tty)"
    echo "Home: $HOME"
    echo "Shell: $SHELL"
} | tee -a "$OUTPUT_FILE"

add_section "2. VENV SERVICE STATUS"
systemctl status setup-quickshell-venv.service --no-pager | tee -a "$OUTPUT_FILE"

add_section "3. VENV DIRECTORY"
if [ -d "$HOME/.local/state/quickshell/.venv" ]; then
    echo "✓ Venv directory exists" | tee -a "$OUTPUT_FILE"
    ls -la "$HOME/.local/state/quickshell/.venv" | tee -a "$OUTPUT_FILE"
else
    echo "✗ Venv directory NOT FOUND" | tee -a "$OUTPUT_FILE"
fi

add_section "4. VENV HEALTH CHECK"
if [ -d "$HOME/.local/state/quickshell/.venv" ]; then
    echo "Venv folder exists. Checking Python execution:" | tee -a "$OUTPUT_FILE"
    if "$HOME/.local/state/quickshell/.venv/bin/python" --version >/dev/null 2>&1; then
        echo "✓ Venv Python is executable: $("$HOME/.local/state/quickshell/.venv/bin/python" --version)" | tee -a "$OUTPUT_FILE"
    else
        echo "✗ Venv Python FAILED to execute" | tee -a "$OUTPUT_FILE"
    fi

    echo "Checking pyvenv.cfg:" | tee -a "$OUTPUT_FILE"
    if [ -f "$HOME/.local/state/quickshell/.venv/pyvenv.cfg" ]; then
        cat "$HOME/.local/state/quickshell/.venv/pyvenv.cfg" | tee -a "$OUTPUT_FILE"
    else
        echo "✗ pyvenv.cfg NOT FOUND" | tee -a "$OUTPUT_FILE"
    fi

    if [ -f "$HOME/.local/state/quickshell/.venv/bin/pip" ]; then
        echo "✓ Venv pip found. Listing packages:" | tee -a "$OUTPUT_FILE"
        "$HOME/.local/state/quickshell/.venv/bin/pip" list 2>&1 | tee -a "$OUTPUT_FILE"
    else
        echo "✗ Venv pip NOT FOUND. Checking site-packages directory:" | tee -a "$OUTPUT_FILE"
        find "$HOME/.local/state/quickshell/.venv/lib/" -maxdepth 2 -name "site-packages" -type d | tee -a "$OUTPUT_FILE"
    fi
else
    echo "✗ Venv directory NOT FOUND" | tee -a "$OUTPUT_FILE"
fi

add_section "5. ENVIRONMENT VARIABLES"
{
    echo "ILLOGICAL_IMPULSE_VIRTUAL_ENV=$ILLOGICAL_IMPULSE_VIRTUAL_ENV"
    echo "XDG_STATE_HOME=$XDG_STATE_HOME"
    echo "XDG_CONFIG_HOME=$XDG_CONFIG_HOME"
    echo "WAYLAND_DISPLAY=$WAYLAND_DISPLAY"
    echo "HYPRLAND_INSTANCE_SIGNATURE=$HYPRLAND_INSTANCE_SIGNATURE"
} | tee -a "$OUTPUT_FILE"

add_section "6. QS WRAPPER & QUICKSHELL BINARY"
if [ -f "/usr/local/bin/qs" ]; then
    echo "✓ Wrapper 'qs' found at /usr/local/bin/qs" | tee -a "$OUTPUT_FILE"
    echo "Content of 'qs' wrapper:" | tee -a "$OUTPUT_FILE"
    cat "/usr/local/bin/qs" | tee -a "$OUTPUT_FILE"
    if [ -x "/usr/local/bin/qs" ]; then
        echo "✓ 'qs' wrapper is executable" | tee -a "$OUTPUT_FILE"
    else
        echo "✗ 'qs' wrapper is NOT EXECUTABLE" | tee -a "$OUTPUT_FILE"
    fi
else
    echo "✗ Wrapper 'qs' NOT FOUND at /usr/local/bin/qs" | tee -a "$OUTPUT_FILE"
fi

if command -v quickshell >/dev/null 2>&1; then
    echo "✓ Quickshell binary found: $(which quickshell)" | tee -a "$OUTPUT_FILE"
    quickshell --version 2>&1 | tee -a "$OUTPUT_FILE"
else
    echo "✗ Quickshell binary NOT FOUND" | tee -a "$OUTPUT_FILE"
fi

add_section "7. QUICKSHELL CONFIG VALIDATION"
if [ -d "$HOME/.config/quickshell" ]; then
    echo "✓ Config root exists: $HOME/.config/quickshell" | tee -a "$OUTPUT_FILE"
    echo "Checking for 'ii' config (suggested by dots-hyprland):" | tee -a "$OUTPUT_FILE"
    if [ -d "$HOME/.config/quickshell/ii" ]; then
        echo "✓ 'ii' config directory exists" | tee -a "$OUTPUT_FILE"
        if [ -f "$HOME/.config/quickshell/ii/shell.qml" ]; then
            echo "✓ main shell.qml found in 'ii' config" | tee -a "$OUTPUT_FILE"
        else
            echo "✗ shell.qml NOT FOUND in 'ii' config" | tee -a "$OUTPUT_FILE"
        fi
    else
        echo "✗ 'ii' config directory NOT FOUND" | tee -a "$OUTPUT_FILE"
        echo "Directories in .config/quickshell:" | tee -a "$OUTPUT_FILE"
        ls -F "$HOME/.config/quickshell" | tee -a "$OUTPUT_FILE"
    fi
else
    echo "✗ Config root directory NOT FOUND" | tee -a "$OUTPUT_FILE"
fi

add_section "8. HYPRLAND ENV CONFIG"
if [ -f "$HOME/.config/hypr/hyprland/env.conf" ]; then
    echo "✓ env.conf exists" | tee -a "$OUTPUT_FILE"
    grep -i "ILLOGICAL_IMPULSE_VIRTUAL_ENV" "$HOME/.config/hypr/hyprland/env.conf" 2>&1 | tee -a "$OUTPUT_FILE"
else
    echo "✗ env.conf NOT FOUND" | tee -a "$OUTPUT_FILE"
fi

add_section "9. HYPRLAND MAIN CONFIG"
if [ -f "$HOME/.config/hypr/hyprland.conf" ]; then
    echo "✓ hyprland.conf exists" | tee -a "$OUTPUT_FILE"
    echo "Checking if env.conf is sourced:" | tee -a "$OUTPUT_FILE"
    grep -i "source.*env.conf" "$HOME/.config/hypr/hyprland.conf" 2>&1 | tee -a "$OUTPUT_FILE"
else
    echo "✗ hyprland.conf NOT FOUND" | tee -a "$OUTPUT_FILE"
fi

add_section "10. HYPRLAND EXEC CONFIGS"
echo "Checking for quickshell autostart:" | tee -a "$OUTPUT_FILE"
grep -r "quickshell\|qs " "$HOME/.config/hypr/" 2>&1 | head -50 | tee -a "$OUTPUT_FILE"

add_section "11. QUICKSHELL PROCESS"
if pgrep -x quickshell >/dev/null 2>&1; then
    echo "✓ Quickshell is RUNNING" | tee -a "$OUTPUT_FILE"
    ps aux | grep -i quickshell | grep -v grep | tee -a "$OUTPUT_FILE"
else
    echo "✗ Quickshell is NOT RUNNING" | tee -a "$OUTPUT_FILE"
fi

add_section "12. HYPRLAND LOGS"
HYPR_LOG="$HOME/.cache/hyprland/hyprland.log"
if [ -f "$HYPR_LOG" ]; then
    echo "✓ Hyprland log found" | tee -a "$OUTPUT_FILE"
    echo "Last 50 lines:" | tee -a "$OUTPUT_FILE"
    tail -50 "$HYPR_LOG" 2>&1 | tee -a "$OUTPUT_FILE"
else
    echo "✗ Hyprland log not found" | tee -a "$OUTPUT_FILE"
fi

add_section "13. CACHED WHEELS"
if [ -d "/var/cache/wheels" ]; then
    WHEEL_COUNT=$(ls /var/cache/wheels/*.whl 2>/dev/null | wc -l)
    TARBALL_COUNT=$(ls /var/cache/wheels/*.tar.gz 2>/dev/null | wc -l)
    echo "Wheels available: $WHEEL_COUNT" | tee -a "$OUTPUT_FILE"
    echo "Source distributions: $TARBALL_COUNT" | tee -a "$OUTPUT_FILE"
    
    echo "" | tee -a "$OUTPUT_FILE"
    echo "Wheel Python versions:" | tee -a "$OUTPUT_FILE"
    ls /var/cache/wheels/*.whl 2>/dev/null | while read wheel; do
        basename "$wheel" | grep -oE "cp3[0-9]+" | head -1
    done | sort | uniq -c | tee -a "$OUTPUT_FILE"
    
    if [ "$TARBALL_COUNT" -gt 0 ]; then
        echo "" | tee -a "$OUTPUT_FILE"
        echo "⚠ WARNING: Source distributions found (should be wheels only)" | tee -a "$OUTPUT_FILE"
        ls /var/cache/wheels/*.tar.gz 2>&1 | tee -a "$OUTPUT_FILE"
    fi
else
    echo "✗ Wheels cache directory not found" | tee -a "$OUTPUT_FILE"
fi

add_section "14. SERVICE LOGS"
echo "=== setup-quickshell-venv.service logs ===" | tee -a "$OUTPUT_FILE"
journalctl -u setup-quickshell-venv.service --no-pager -n 50 2>&1 | tee -a "$OUTPUT_FILE"

echo "" | tee -a "$OUTPUT_FILE"
echo "=== configure-liveuser-groups.service logs ===" | tee -a "$OUTPUT_FILE"
journalctl -u configure-liveuser-groups.service --no-pager -n 50 2>&1 | tee -a "$OUTPUT_FILE"

add_section "15. SYSTEM INFO"
{
    echo "Kernel: $(uname -r)"
    echo "Uptime: $(uptime -p)"
    echo "Memory: $(free -h | grep Mem | awk '{print $3 "/" $2}')"
    echo "Disk: $(df -h / | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}')"
} | tee -a "$OUTPUT_FILE"

add_section "16. NETWORK STATUS"
{
    echo "Network interfaces:"
    ip -br addr 2>&1
    echo ""
    echo "DNS resolution test:"
    ping -c 1 archlinux.org >/dev/null 2>&1 && echo "✓ Internet connectivity OK" || echo "✗ No internet connectivity"
} | tee -a "$OUTPUT_FILE"

add_section "17. PACKAGE DATABASE"
{
    echo "Checking local_repo database:"
    if [ -f "/var/lib/pacman/sync/local_repo.db" ]; then
        echo "✓ local_repo database exists"
        echo "Packages in local_repo: $(pacman -Sl local_repo 2>/dev/null | wc -l)"
    else
        echo "✗ local_repo database not found"
    fi
} | tee -a "$OUTPUT_FILE"

add_section "18. MANUAL QUICKSHELL START TEST"
echo "Attempting to start quickshell manually..." | tee -a "$OUTPUT_FILE"
timeout 5 quickshell 2>&1 | head -20 | tee -a "$OUTPUT_FILE"

add_section "SUMMARY"
{
    ISSUES=0
    
    # Check critical components
    if ! systemctl is-active --quiet setup-quickshell-venv.service; then
        echo "✗ Venv service failed"
        ((ISSUES++))
    fi
    
    if ! command -v quickshell >/dev/null 2>&1; then
        echo "✗ Quickshell binary not found"
        ((ISSUES++))
    fi
    
    if ! pgrep -x quickshell >/dev/null 2>&1; then
        echo "✗ Quickshell not running"
        ((ISSUES++))
    fi
    
    if [ ! -d "$HOME/.local/state/quickshell/.venv" ]; then
        echo "✗ Venv directory missing"
        ((ISSUES++))
    fi
    
    echo ""
    echo "Total issues found: $ISSUES"
    
    if [ $ISSUES -eq 0 ]; then
        echo "✓ All checks passed!"
    else
        echo "⚠ Issues detected - see details above"
    fi
} | tee -a "$OUTPUT_FILE"

echo "" | tee -a "$OUTPUT_FILE"
echo "==========================================" | tee -a "$OUTPUT_FILE"
echo "==========================================" | tee -a "$OUTPUT_FILE"

# Upload to pastebin
echo ""
echo "Uploading report to pastebin..."

PASTEBIN_URL=""

# Try termbin.com with netcat (preferred)
if command -v nc >/dev/null 2>&1; then
    PASTEBIN_URL=$(cat "$OUTPUT_FILE" | nc termbin.com 9999 2>/dev/null)
    if [ -n "$PASTEBIN_URL" ]; then
        echo "✓ Report uploaded to: $PASTEBIN_URL"
        echo "$PASTEBIN_URL" | tee /tmp/endos-debug-url.txt
        exit 0
    fi
fi

# Fallback to ix.io with curl
if command -v curl >/dev/null 2>&1; then
    PASTEBIN_URL=$(curl -s -F 'f:1=<-' ix.io < "$OUTPUT_FILE" 2>/dev/null)
    if [ -n "$PASTEBIN_URL" ] && [[ "$PASTEBIN_URL" =~ ^http ]]; then
        echo "✓ Report uploaded to: $PASTEBIN_URL"
        echo "$PASTEBIN_URL" | tee /tmp/endos-debug-url.txt
        exit 0
    fi
fi

# If upload failed, show local file location
echo "✗ Failed to upload to pastebin"
echo "Report saved locally at: $OUTPUT_FILE"
echo ""
echo "You can manually upload it or share the file."
