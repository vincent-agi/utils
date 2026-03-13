#!/bin/bash

LOGFILE="$HOME/fail2ban_setup_$(date +%Y%m%d_%H%M%S).log"

print_section() {
    echo "==== $1 ====" | tee -a "$LOGFILE"
}

prompt_remote_info() {
    print_section "Remote Server Information"
    read -p "Remote server IP address or DNS: " REMOTE_HOST
    read -p "Remote username (root or sudo user): " REMOTE_USER
    read -p "SSH port (default 22): " REMOTE_PORT
    REMOTE_PORT=${REMOTE_PORT:-22}
}

install_fail2ban() {
    print_section "Installing fail2ban on remote server"
    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "sudo apt-get update && sudo apt-get install -y fail2ban" | tee -a "$LOGFILE"
}

prompt_fail2ban_settings() {
    print_section "Configure fail2ban settings"
    read -p "Ban time in seconds (default 600): " BAN_TIME
    BAN_TIME=${BAN_TIME:-600}
    read -p "Max retry attempts (default 3): " MAX_RETRY
    MAX_RETRY=${MAX_RETRY:-3}
    read -p "Find time in seconds (default 600): " FIND_TIME
    FIND_TIME=${FIND_TIME:-600}
    read -p "Monitored services (comma separated, e.g. sshd,apache): " SERVICES
    SERVICES=${SERVICES:-sshd}

    read -p "Ignore IPs (comma separated, e.g. 127.0.0.1,192.168.1.1): " IGNORE_IP
    IGNORE_IP=${IGNORE_IP:-""}

    read -p "Log level (default INFO, options: INFO, WARNING, ERROR, DEBUG): " LOG_LEVEL
    LOG_LEVEL=${LOG_LEVEL:-INFO}

    read -p "Action (default: ban only, options: action_mw, action_mwl, action): " ACTION
    ACTION=${ACTION:-action}

    read -p "Email address for notifications (leave empty for none): " EMAIL
    EMAIL=${EMAIL:-""}

    read -p "Jail log path (default /var/log/auth.log): " JAIL_LOGPATH
    JAIL_LOGPATH=${JAIL_LOGPATH:-/var/log/auth.log}
}

apply_fail2ban_config() {
    print_section "Applying fail2ban configuration"
    CONFIG="[DEFAULT]\nbantime = $BAN_TIME\nfindtime = $FIND_TIME\nmaxretry = $MAX_RETRY\n\n"
    for service in $(echo $SERVICES | tr ',' ' '); do
        CONFIG+="[${service}]\nenabled = true\n"
    done
    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "echo -e '$CONFIG' | sudo tee /etc/fail2ban/jail.local > /dev/null"
}

validate_fail2ban() {
    print_section "Validating fail2ban status and configuration"
    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "sudo systemctl status fail2ban && sudo fail2ban-client status" | tee -a "$LOGFILE"
}

display_summary_and_confirm() {
    print_section "Summary and User Confirmation"
    echo "Fail2ban will be enabled with the following settings:" | tee -a "$LOGFILE"
    echo "Ban time: $BAN_TIME seconds" | tee -a "$LOGFILE"
    echo "Find time: $FIND_TIME seconds" | tee -a "$LOGFILE"
    echo "Max retry: $MAX_RETRY" | tee -a "$LOGFILE"
    echo "Monitored services: $SERVICES" | tee -a "$LOGFILE"
    read -p "Do you approve enabling fail2ban with these settings? (N/y): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Cancelled as requested." | tee -a "$LOGFILE"
        exit 3
    fi
}

enable_fail2ban() {
    print_section "Enabling fail2ban"
    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "sudo systemctl enable fail2ban && sudo systemctl restart fail2ban" | tee -a "$LOGFILE"
    echo "Fail2ban has been enabled and restarted on $REMOTE_HOST." | tee -a "$LOGFILE"
}

main() {
    prompt_remote_info
    install_fail2ban
    prompt_fail2ban_settings
    apply_fail2ban_config
    validate_fail2ban
    display_summary_and_confirm
    enable_fail2ban
    print_section "Procedure Complete"
    echo "All actions have been logged in $LOGFILE"
}

main
