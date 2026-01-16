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
        
        if [ -d "$DOTS_SRC" ]; then
            # Copy all files (including hidden)
            cp -a "$DOTS_SRC/." "$LIVE_HOME/" 2>/dev/null
            mkdir -p "$LIVE_HOME/.config/hypr"
            
            # Fix Permissions
            chown -R "$LIVE_USER:$LIVE_USER" "$LIVE_HOME"
        else
             echo "ERROR: Dotfiles not found at $DOTS_SRC"
        fi
    fi

    echo "Starting Hyprland as $LIVE_USER..."
    
    # VM Compatibility Fixes
    export WLR_NO_HARDWARE_CURSORS=1
    export WLR_RENDERER_ALLOW_SOFTWARE=1
    
    # Launch as user
    if command -v Hyprland &> /dev/null; then
        # Switch to user and run Hyprland
        # usage of exec su - ... might handle tty ownership differently
        exec su - "$LIVE_USER" -c "export WLR_NO_HARDWARE_CURSORS=1; export WLR_RENDERER_ALLOW_SOFTWARE=1; Hyprland" || echo "Hyprland exited."
    else
        echo "Hyprland not found. Dropping to shell."
    fi
fi
