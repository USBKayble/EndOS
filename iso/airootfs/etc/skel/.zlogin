
# Automated EndOS Install Logic
if [ ! -f ~/.config/dots-hyprland-installed ]; then
    /usr/local/bin/post-install-dots.sh
    mkdir -p ~/.config
    touch ~/.config/dots-hyprland-installed
fi

exec start-hyprland
