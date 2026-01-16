# Auto-start Archinstall wrapper for EndOS

if [[ -z $DISPLAY ]] && [[ $(tty) == /dev/tty1 ]]; then
    # Auto-start archinstall with config
    archinstall --config /root/config.json
    
    # After install, run our setup script in the chroot
    if [ -f /mnt/archinstall/root/setup_arch.sh ]; then
        echo "Running EndOS Post-Install Setup..."
        arch-chroot /mnt/archinstall /root/setup_arch.sh
    fi
    
    # Reboot or drop to shell
    exec zsh
fi
