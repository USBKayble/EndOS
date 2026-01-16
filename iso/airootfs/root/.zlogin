# EndOS Live Environment Entrypoint

if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
    # Create Live User (if not exists)
    LIVE_USER="liveuser"
    if ! id "$LIVE_USER" &>/dev/null; then
        echo "Creating live user: $LIVE_USER..."
        useradd -m -G wheel -s /bin/zsh "$LIVE_USER"
        passwd -d "$LIVE_USER" # No password
        echo "$LIVE_USER ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    fi
    
    # Deploy Dotfiles for Live User
    LIVE_HOME="/home/$LIVE_USER"
    if [ ! -d "$LIVE_HOME/.config/hypr" ]; then
        echo "Setting up dotfiles for $LIVE_USER..."
        DOTS_SRC="/usr/share/endos/dots"
        
        # Smart Detect: Check for 'dots' subdirectory
        if [ -d "$DOTS_SRC/dots" ]; then
            DOTS_SUBDIR="$DOTS_SRC/dots"
        else
            DOTS_SUBDIR="$DOTS_SRC"
        fi

        if [ -d "$DOTS_SUBDIR" ]; then
                echo "Deploying dotfiles from $DOTS_SUBDIR..."
                
                # Smart Detect: Where should we copy?
                if [ -d "$DOTS_SUBDIR/.config" ]; then
                    # Structure: dots/.config/hypr -> ~/ (classic stow)
                    echo "Detailed structure detected: dots/.config -> copying to ~/"
                    cp -a "$DOTS_SUBDIR/." "$LIVE_HOME/" 2>/dev/null
                elif [ -d "$DOTS_SUBDIR/hypr" ]; then
                    # Structure: dots/hypr -> ~/.config/ (flat config dir)
                    echo "Flat structure detected: dots/hypr -> copying to ~/.config/"
                    mkdir -p "$LIVE_HOME/.config"
                    cp -a "$DOTS_SUBDIR/." "$LIVE_HOME/.config/" 2>/dev/null
                else
                    # Fallback
                    echo "Unknown structure. Copying to ~/.config/ as a best guess..."
                    mkdir -p "$LIVE_HOME/.config"
                    cp -a "$DOTS_SUBDIR/." "$LIVE_HOME/.config/" 2>/dev/null
                fi
                
            else
                echo "WARNING: $DOTS_SUBDIR not found. Falling back to root copy..."
                cp -a "$DOTS_SRC/." "$LIVE_HOME/" 2>/dev/null
            fi
            
            mkdir -p "$LIVE_HOME/.config/hypr"
            
            # Fix Permissions
            chown -R "$LIVE_USER:$LIVE_USER" "$LIVE_HOME"
            
            # Create a visible file so 'ls' isn't empty
            echo "Welcome to EndOS! Run 'setup' to install." > "$LIVE_HOME/README.txt"
            chown "$LIVE_USER:$LIVE_USER" "$LIVE_HOME/README.txt"
        else
             echo "ERROR: Dotfiles not found at $DOTS_SRC"
        fi
    fi

    echo "Starting Hyprland as $LIVE_USER..."
    
    # VM Compatibility Fixes (Conditional)
    if lspci | grep -Ei "vmware|virtualbox|qemu|kvm|hyper-v" &> /dev/null; then
        echo "VM Environment Detected. Enabling software cursors..."
        export WLR_NO_HARDWARE_CURSORS=1
        export WLR_RENDERER_ALLOW_SOFTWARE=1
    else
        # Optional: Force software cursors for Nvidia if needed, but modern Hyprland is better.
        # For now, let's keep it clean for real hardware.
        # If user has issues, they can set it manually.
        :
    fi
    
    # Launch as user
    if command -v Hyprland &> /dev/null; then
        # Switch to user and run Hyprland
        # We need to set XDG_RUNTIME_DIR manually if not handled by logind/PAM correctly in this context
        # And ensure the user has ownership of it.
        
        USER_RUNTIME_DIR="/run/user/$(id -u $LIVE_USER)"
        if [ ! -d "$USER_RUNTIME_DIR" ]; then
            mkdir -p "$USER_RUNTIME_DIR"
            chown "$LIVE_USER:$LIVE_USER" "$USER_RUNTIME_DIR"
            chmod 700 "$USER_RUNTIME_DIR"
        fi
        
        exec su - "$LIVE_USER" -c "export XDG_RUNTIME_DIR=$USER_RUNTIME_DIR; [ -n \"$WLR_NO_HARDWARE_CURSORS\" ] && export WLR_NO_HARDWARE_CURSORS=1; [ -n \"$WLR_RENDERER_ALLOW_SOFTWARE\" ] && export WLR_RENDERER_ALLOW_SOFTWARE=1; Hyprland" || echo "Hyprland exited."
    else
        echo "Hyprland not found. Dropping to shell."
    fi
fi
