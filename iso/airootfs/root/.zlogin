# Auto-start Archinstall wrapper for EndOS

if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
    echo "=========================================="
    echo "Welcome to the EndOS Installer!"
    echo "=========================================="
    echo "This wizard will install Arch Linux with EndOS defaults."
    echo "Hostname: EndOS | Profile: Minimal | Network: NetworkManager"
    echo ""
    read -t 10 -p "Press Enter to start installation (or Ctrl+C to exit to shell)..." || echo "Starting..."
    
    # run archinstall
    archinstall --config /root/config.json
    install_exit=$?

    if [ $install_exit -eq 0 ]; then
        echo "Arch Linux installation complete."
        echo "Copying setup_arch.sh to the new system..."
        
        # Copy setup script to the new root
        cp /root/setup_arch.sh /mnt/root/setup_arch.sh
        chmod +x /mnt/root/setup_arch.sh
        
        echo "=========================================="
        echo "Installing EndOS customization (Post-Install)..."
        echo "=========================================="
        
        # We need to run the setup script inside the chroot.
        # However, setup_arch.sh is interactive (asks for password/confirmation).
        # We will wrap it to run inside the chroot. 
        # Since it's a fresh install, we might need to set a root password or use arch-chroot behavior.
        
        echo "Running post-install script in chroot..."
        # NOTE: setup_arch.sh is designed to handle being run as user with sudo. 
        # Inside chroot /root, we are root. 
        
        arch-chroot /mnt /root/setup_arch.sh
        
        echo "=========================================="
        echo "EndOS Installation Complete!"
        echo "Rebooting in 10 seconds..."
        sleep 10
        reboot
    else
        echo "Archinstall exited with error $install_exit."
        echo "Dropping to shell."
    fi
fi
