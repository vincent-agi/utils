#!/bin/bash

LOGFILE="$HOME/ssh_setup_$(date +%Y%m%d_%H%M%S).log"

print_section() {
    echo "==== $1 ====" | tee -a "$LOGFILE"
}

generate_ssh_key() {
    print_section "SSH Key Generation"
    read -p "Enter the name for the new SSH key file (without path, e.g.: id_myserver): " KEYNAME
    KEYPATH="$HOME/.ssh/$KEYNAME"
    if [[ -f "$KEYPATH" || -f "$KEYPATH.pub" ]]; then
        echo "Error: A key with this name already exists ($KEYPATH). Aborting." | tee -a "$LOGFILE"
        exit 1
    fi
    read -p "Enter a passphrase for the key (leave empty for none): " -s KEYPASS
    echo
    ssh-keygen -t ed25519 -f "$KEYPATH" -N "$KEYPASS" | tee -a "$LOGFILE"
    chmod 600 "$KEYPATH"
    chmod 644 "$KEYPATH.pub"
    eval "$(ssh-agent -s)" | tee -a "$LOGFILE"
    ssh-add "$KEYPATH" | tee -a "$LOGFILE"
}

get_remote_info() {
    print_section "Remote Server Connection Info"
    read -p "Remote server IP address or DNS: " REMOTE_HOST
    read -p "Remote username (root or sudo user): " REMOTE_USER
    read -p "SSH port (default 22): " REMOTE_PORT
    REMOTE_PORT=${REMOTE_PORT:-22}
}

transfer_public_key() {
    print_section "Transferring Public Key to Server"
    MAX_ATTEMPTS=3
    ATTEMPT=1
    while (( ATTEMPT <= MAX_ATTEMPTS )); do
        SSHCOPYID_OUTPUT=$(ssh-copy-id -i "$KEYPATH.pub" -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" 2>&1 | tee -a "$LOGFILE")
        if echo "$SSHCOPYID_OUTPUT" | grep -q "REMOTE HOST IDENTIFICATION HAS CHANGED"; then
            echo "$SSHCOPYID_OUTPUT" | tee -a "$LOGFILE"
            OFFENDING_LINE=$(echo "$SSHCOPYID_OUTPUT" | grep "Offending" | grep -o 'known_hosts:[0-9]*' | cut -d: -f2)
            if [[ -n "$OFFENDING_LINE" ]]; then
                echo "Le fichier known_hosts contient une entrée conflictuelle à la ligne $OFFENDING_LINE." | tee -a "$LOGFILE"
                read -p "Voulez-vous supprimer cette entrée et réessayer ? (y/N): " CONFIRM_REMOVE
                if [[ "$CONFIRM_REMOVE" == "y" || "$CONFIRM_REMOVE" == "Y" ]]; then
                    sed -i '' "${OFFENDING_LINE}d" "$HOME/.ssh/known_hosts"
                    echo "Entrée supprimée. Nouvelle tentative de transfert de la clé..." | tee -a "$LOGFILE"
                    ((ATTEMPT++))
                    continue
                else
                    echo "Transfert annulé par l'utilisateur." | tee -a "$LOGFILE"
                    exit 4
                fi
            else
                echo "Impossible de déterminer la ligne conflictuelle dans known_hosts. Veuillez vérifier manuellement." | tee -a "$LOGFILE"
                exit 5
            fi
        elif echo "$SSHCOPYID_OUTPUT" | grep -q "Permission denied" || echo "$SSHCOPYID_OUTPUT" | grep -q "Too many authentication failures"; then
            echo "Erreur d'authentification : $SSHCOPYID_OUTPUT" | tee -a "$LOGFILE"
            read -p "Le serveur refuse l'accès. Voulez-vous réessayer ? (y/N): " RETRY
            if [[ "$RETRY" == "y" || "$RETRY" == "Y" ]]; then
                ((ATTEMPT++))
                continue
            else
                echo "Transfert annulé par l'utilisateur." | tee -a "$LOGFILE"
                exit 8
            fi
        else
            break
        fi
    done
    if (( ATTEMPT > MAX_ATTEMPTS )); then
        echo "Trop de tentatives. Abandon." | tee -a "$LOGFILE"
        exit 9
    fi
}

verify_key_on_server() {
    print_section "Verifying Key on Server"
    MAX_ATTEMPTS=3
    ATTEMPT=1
    while (( ATTEMPT <= MAX_ATTEMPTS )); do
        VERIFY_OUTPUT=$(ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "grep \"$(cat $KEYPATH.pub | cut -d' ' -f2)\" ~/.ssh/authorized_keys" 2>&1)
        if echo "$VERIFY_OUTPUT" | grep -q "REMOTE HOST IDENTIFICATION HAS CHANGED"; then
            echo "$VERIFY_OUTPUT" | tee -a "$LOGFILE"
            OFFENDING_LINE=$(echo "$VERIFY_OUTPUT" | grep "Offending" | grep -o 'known_hosts:[0-9]*' | cut -d: -f2)
            if [[ -n "$OFFENDING_LINE" ]]; then
                echo "Le fichier known_hosts contient une entrée conflictuelle à la ligne $OFFENDING_LINE." | tee -a "$LOGFILE"
                read -p "Voulez-vous supprimer cette entrée et réessayer ? (y/N): " CONFIRM_REMOVE
                if [[ "$CONFIRM_REMOVE" == "y" || "$CONFIRM_REMOVE" == "Y" ]]; then
                    sed -i '' "${OFFENDING_LINE}d" "$HOME/.ssh/known_hosts"
                    echo "Entrée supprimée. Nouvelle tentative de vérification..." | tee -a "$LOGFILE"
                    ((ATTEMPT++))
                    continue
                else
                    echo "Vérification annulée par l'utilisateur." | tee -a "$LOGFILE"
                    exit 6
                fi
            else
                echo "Impossible de déterminer la ligne conflictuelle dans known_hosts. Veuillez vérifier manuellement." | tee -a "$LOGFILE"
                exit 7
            fi
        elif echo "$VERIFY_OUTPUT" | grep -q "Permission denied" || echo "$VERIFY_OUTPUT" | grep -q "Too many authentication failures"; then
            echo "Erreur d'authentification : $VERIFY_OUTPUT" | tee -a "$LOGFILE"
            read -p "Le serveur refuse l'accès. Voulez-vous réessayer ? (y/N): " RETRY
            if [[ "$RETRY" == "y" || "$RETRY" == "Y" ]]; then
                ((ATTEMPT++))
                continue
            else
                echo "Vérification annulée par l'utilisateur." | tee -a "$LOGFILE"
                exit 10
            fi
        else
            break
        fi
    done
    if (( ATTEMPT > MAX_ATTEMPTS )); then
        echo "Trop de tentatives. Abandon." | tee -a "$LOGFILE"
        exit 11
    fi
    if [[ "$VERIFY_OUTPUT" == "" ]]; then
        echo "Clé vérifiée sur le serveur." | tee -a "$LOGFILE"
    else
        echo "$VERIFY_OUTPUT" | tee -a "$LOGFILE"
        echo "Error: The key does not seem to be present on the server. Aborting." | tee -a "$LOGFILE"
        exit 2
    fi
}

update_ssh_config() {
    print_section "Updating ~/.ssh/config"
    SSH_CONFIG="$HOME/.ssh/config"
    BACKUP_CONFIG="$SSH_CONFIG.bak.$(date +%Y%m%d_%H%M%S)"
    if [[ -f "$SSH_CONFIG" ]]; then
        cp "$SSH_CONFIG" "$BACKUP_CONFIG"
        echo "Backup of ssh_config file saved as $BACKUP_CONFIG" | tee -a "$LOGFILE"
    else
        touch "$SSH_CONFIG"
        chmod 600 "$SSH_CONFIG"
    fi
    read -p "Host alias to use in ssh_config (e.g.: myserver): " SSH_HOST_ALIAS
    if grep -q "Host $SSH_HOST_ALIAS" "$SSH_CONFIG"; then
        echo "Warning: A Host entry $SSH_HOST_ALIAS already exists in ssh_config." | tee -a "$LOGFILE"
        read -p "Replace existing entry? (Y/n) " REPLACE
        if [[ "$REPLACE" != "Y" && "$REPLACE" != "y" ]]; then
            echo "Modification of ssh_config cancelled." | tee -a "$LOGFILE"
        else
            awk "/Host $SSH_HOST_ALIAS/{flag=1;next}/^Host /{flag=0}flag{next}!flag{print}" "$SSH_CONFIG" > "$SSH_CONFIG.tmp" && mv "$SSH_CONFIG.tmp" "$SSH_CONFIG"
        fi
    fi
    cat <<EOF >> "$SSH_CONFIG"

Host $SSH_HOST_ALIAS
    HostName $REMOTE_HOST
    User $REMOTE_USER
    Port $REMOTE_PORT
    IdentityFile $KEYPATH
    IdentitiesOnly yes
EOF
    echo "Entry added to ssh_config:" | tee -a "$LOGFILE"
    echo "Host $SSH_HOST_ALIAS\n    HostName $REMOTE_HOST\n    User $REMOTE_USER\n    Port $REMOTE_PORT\n    IdentityFile $KEYPATH\n    IdentitiesOnly yes" | tee -a "$LOGFILE"
}

execute_remote_script() {
    print_section "Download and Execute Remote Script"
    SCRIPT_URL="https://raw.githubusercontent.com/vincent-agi/utils/refs/heads/main/bash/sshkey-config.sh"
    SCRIPT_SHA256=$(curl -sSL $SCRIPT_URL | sha256sum | cut -d' ' -f1)
    echo "SHA256 of downloaded script: $SCRIPT_SHA256" | tee -a "$LOGFILE"
    echo "--- Remote script content ---" | tee -a "$LOGFILE"
    curl -sSL $SCRIPT_URL | tee -a "$LOGFILE"
    echo "--- End of script ---" | tee -a "$LOGFILE"
    echo "This script configures the SSH server: changes the SSH port, disables password authentication, enables SSH key authentication, and restarts the SSH service. It is intended to harden SSH access on the remote server." | tee -a "$LOGFILE"
    echo "Please review the script above."
    read -p "Do you explicitly approve running this script on $REMOTE_HOST? (y/N): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        echo "Cancelled as requested." | tee -a "$LOGFILE"
        exit 3
    fi
    ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "curl -sSL $SCRIPT_URL | bash" | tee -a "$LOGFILE"
}

main() {
    generate_ssh_key
    get_remote_info
    transfer_public_key
    verify_key_on_server
    update_ssh_config
    execute_remote_script
    print_section "Optional Security Enhancements"
    echo "You can now choose to run an additional security script on the remote server:" | tee -a "$LOGFILE"
    echo "1) SSH hardening (sshd-secure-config.sh)" | tee -a "$LOGFILE"
    echo "2) Fail2ban setup (fail2ban-setup-interactive.sh)" | tee -a "$LOGFILE"
    echo "3) None" | tee -a "$LOGFILE"
    read -p "Select an option [1/2/3]: " SECURITY_CHOICE
    case $SECURITY_CHOICE in
        1)
            print_section "Running sshd-secure-config.sh on remote server"
            scp -P "$REMOTE_PORT" "$(dirname "$0")/sshd-secure-config.sh" "$REMOTE_USER@$REMOTE_HOST:~/sshd-secure-config.sh"
            ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "sudo bash ~/sshd-secure-config.sh" | tee -a "$LOGFILE"
            ;;
        2)
            print_section "Running fail2ban-setup-interactive.sh on remote server"
            scp -P "$REMOTE_PORT" "$(dirname "$0")/fail2ban-setup-interactive.sh" "$REMOTE_USER@$REMOTE_HOST:~/fail2ban-setup-interactive.sh"
            ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "sudo bash ~/fail2ban-setup-interactive.sh" | tee -a "$LOGFILE"
            ;;
        *)
            echo "No additional security script selected." | tee -a "$LOGFILE"
            ;;
    esac
    print_section "Procedure Complete"
    echo "All actions have been logged in $LOGFILE"
}

main
