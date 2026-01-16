# EndOS Live Environment Entrypoint

if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
    # Set up transient home for Hyprland if needed
    if [ ! -d ~/.config/hypr ]; then
        echo "Setting up EndOS Live Environment..."
        # Copy dotfiles if they exist in skel (deployed by CI)
        if [ -d /etc/skel/dots-hyprland ]; then
            cp -r /etc/skel/dots-hyprland/* ~/ 2>/dev/null
            mkdir -p ~/.config/hypr
        fi
    fi

    echo "Starting Hyprland..."
    # Attempt to start Hyprland
    if command -v Hyprland &> /dev/null; then
        exec Hyprland
    else
        echo "Hyprland not found. Dropping to shell."
        echo "Run './setup_arch.sh' to install."
    fi
fi
