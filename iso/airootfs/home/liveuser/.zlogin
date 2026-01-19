
# EndOS First Boot Setup
LOG_FILE="/tmp/endos-boot.log"

echo "[$(date)] .zlogin started for user: $(whoami)" | tee -a "$LOG_FILE"
echo "[$(date)] TTY: $(tty)" | tee -a "$LOG_FILE"

if [ ! -f ~/.config/dots-hyprland-installed ]; then
    echo "[$(date)] Running first-boot setup..." | tee -a "$LOG_FILE"
    /usr/local/bin/post-install-dots.sh 2>&1 | tee -a "$LOG_FILE" || true
    mkdir -p ~/.config
    touch ~/.config/dots-hyprland-installed
    echo "[$(date)] First-boot setup complete" | tee -a "$LOG_FILE"
fi

echo "[$(date)] Starting Hyprland..." | tee -a "$LOG_FILE"
exec start-hyprland
