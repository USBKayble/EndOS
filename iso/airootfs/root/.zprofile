# EndOS Live Environment Entrypoint

# Redirect ALL output to log file for debugging
exec >/log/zlogin.log 2>&1

echo "See /log/zlogin.log for details."

if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
    
    echo "Starting Hyprland as $(whoami)..."
    
    # VM Compatibility Fixes (Conditional)
    if lspci | grep -Ei "vmware|virtualbox|qemu|kvm|hyper-v" &> /dev/null; then
        echo "VM Environment Detected. Enabling software cursors..."
        export WLR_NO_HARDWARE_CURSORS=1
        export WLR_RENDERER_ALLOW_SOFTWARE=1
    fi
    
    # Launch Hyprland
    # The binary is typically 'Hyprland' (capital H), but we check both.
    BIN_HYPRLAND="Hyprland"
    if ! command -v Hyprland &> /dev/null; then
        if command -v hyprland &> /dev/null; then
            BIN_HYPRLAND="hyprland"
        fi
    fi

    if command -v "$BIN_HYPRLAND" &> /dev/null; then
        # We need to set XDG_RUNTIME_DIR manually if not handled by logind/PAM correctly in this context
        if [ -z "$XDG_RUNTIME_DIR" ]; then
            export XDG_RUNTIME_DIR="/run/user/$(id -u)"
            if [ ! -d "$XDG_RUNTIME_DIR" ]; then
                mkdir -p "$XDG_RUNTIME_DIR"
                chmod 700 "$XDG_RUNTIME_DIR"
            fi
        fi
        
        # Add alias for convenience if dropping to shell
        alias hyprland="$BIN_HYPRLAND"
        
        exec "$BIN_HYPRLAND" || echo "Hyprland exited."
    else
        echo "Hyprland binary not found. Dropping to shell."
    fi
fi
