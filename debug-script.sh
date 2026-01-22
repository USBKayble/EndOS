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

# 0. HOTFIX: Apply qs wrapper fix
log "APPLYING HOTFIX"
echo "Overwriting /usr/local/bin/qs with corrected content..." | tee -a "$OUTPUT_FILE"

# using cat + heredoc to write the file, ensuring LF endings
sudo bash -c "cat > /usr/local/bin/qs" << 'EOF'
#!/usr/bin/env bash
# Resolve venv path: use env var if set, otherwise default
VENV_PATH="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}"

# Activate the virtual environment if it exists
if [ -f "$VENV_PATH/bin/activate" ]; then
    source "$VENV_PATH/bin/activate"
fi

exec quickshell "$@"
EOF

echo "Fixing permissions..." | tee -a "$OUTPUT_FILE"
sudo chmod +x /usr/local/bin/qs
ls -l /usr/local/bin/qs | tee -a "$OUTPUT_FILE"

# 1. Check Service & Venv
log "Venv Service & Directory"
systemctl status setup-quickshell-venv.service --no-pager | tee -a "$OUTPUT_FILE"
echo "" | tee -a "$OUTPUT_FILE"
ls -la "$HOME/.local/state/quickshell/.venv/bin" | tee -a "$OUTPUT_FILE"

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
VENV_VAR="${ILLOGICAL_IMPULSE_VIRTUAL_ENV:-$HOME/.local/state/quickshell/.venv}"
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
