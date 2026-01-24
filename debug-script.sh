#!/bin/bash
# EndOS Quickshell Targeted Debugger

OUTPUT_FILE="/tmp/endos-debug-qs-$(date +%Y%m%d-%H%M%S).txt"

log() {
    echo "" | tee -a "$OUTPUT_FILE"
    echo ">>> $1" | tee -a "$OUTPUT_FILE"
    echo "------------------------------------------" | tee -a "$OUTPUT_FILE"
}

# Header
{
    echo "EndOS Quickshell Targeted Report"
    echo "Date: $(date)"
    echo "User: $(whoami)"
} > "$OUTPUT_FILE"

# 0. Hotfix removed - wrapper is handled by ISO build


# 1. Check Service & Venv
log "Venv Service & Directory"
# Service is deleted, checking path directly
ls -la "/usr/share/quickshell/venv/bin" | tee -a "$OUTPUT_FILE"

# 2. Check Wrapper Script
log "Wrapper Script Content (/usr/local/bin/qs)"
if [ -f "/usr/local/bin/qs" ]; then
    cat "/usr/local/bin/qs" | tee -a "$OUTPUT_FILE"
else
    echo "MISSING: /usr/local/bin/qs" | tee -a "$OUTPUT_FILE"
fi

# 3. Environment Check
log "Environment Variables"
grep "ILLOGICAL_IMPULSE_VIRTUAL_ENV" "$HOME/.config/hypr/hyprland/env.conf" | tee -a "$OUTPUT_FILE"

# 4. CRITICAL: Runtime Test
log "TEST: Running 'qs -c ii'"
echo "Attempting to run qs with 'ii' config (timeout 5s)..." | tee -a "$OUTPUT_FILE"

# We run qs and capture BOTH stdout and stderr
# We use timeout to stop it if it hangs (which would be a 'success' for a GUI app, but we want to see startup logs)
timeout 5s qs -c ii > /tmp/qs-output.log 2>&1
EXIT_CODE=$?

echo "Exit Code: $EXIT_CODE (124=timeout/running, other=crash)" | tee -a "$OUTPUT_FILE"
echo "--- Output Log ---" | tee -a "$OUTPUT_FILE"
cat /tmp/qs-output.log | tee -a "$OUTPUT_FILE"

# 5. Check Python Interior
log "TEST: Python Module Path check inside Wrapper"
# We invoke python through the wrapper logic to see path
VENV_VAR="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-/usr/share/quickshell/venv}"
bash -c "source $VENV_VAR/bin/activate && python -c 'import sys; print(sys.path)'" 2>&1 | tee -a "$OUTPUT_FILE"

# Upload
log "Upload"
if command -v nc >/dev/null 2>&1; then
    URL=$(cat "$OUTPUT_FILE" | nc termbin.com 9999 2>/dev/null)
    echo "Report uploaded to: $URL"
    echo "$URL" > /tmp/endos-debug-url.txt
else
    echo "Netcat (nc) not found. Saved to $OUTPUT_FILE"
fi
