# EndOS Login Logging
LOG_FILE="/tmp/endos-login.log"

echo "[$(date)] .zlogin executed for user: $(whoami)" | tee -a "$LOG_FILE"
echo "[$(date)] TTY: $(tty)" | tee -a "$LOG_FILE"
