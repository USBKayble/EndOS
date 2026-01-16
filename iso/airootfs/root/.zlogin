# EndOS Live Environment Entrypoint

if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
    # Set up transient home for Hyprland if needed
    if [ ! -d ~/.config/hypr ]; then
        echo "Setting up EndOS Live Environment..."
        
        # Source location from CI injection
        DOTS_SRC="/usr/share/endos/dots"
        
        if [ -d "$DOTS_SRC" ]; then
            echo "Deploying dotfiles from $DOTS_SRC..."
            cp -r "$DOTS_SRC"/* ~/ 2>/dev/null
            mkdir -p ~/.config/hypr
        else
            echo "ERROR: Dotfiles source not found at $DOTS_SRC"
        fi
    fi

    echo "Starting Hyprland..."
    
    # VM Compatibility Fixes (for Live ISO)
    export WLR_NO_HARDWARE_CURSORS=1
    export WLR_RENDERER_ALLOW_SOFTWARE=1
    
    # Attempt to start Hyprland with logging
    if command -v Hyprland &> /dev/null; then
        # Check if dotfiles were actually copied
        if [ ! -f ~/.config/hypr/hyprland.conf ]; then
             echo "Warning: Hyprland config not found in ~/.config/hypr/"
             gum style --foreground 196 "Dotfiles missing! Hyprland might crash."
        fi
        
        # Launch
        exec Hyprland || echo "Hyprland crashed/exited."
    else
        echo "Hyprland not found. Dropping to shell."
        echo "Run './setup_arch.sh' to install."
    fi
fi
