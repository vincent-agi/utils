#!/bin/bash

SSH_CONFIG="/etc/ssh/sshd_config"

get_ssh_port() {
   local port
   local reserved_ports=(22 80 443 21 25 110 143 3306 5432 6379 8080 8443 8888 9000 10000 27017)
   while true; do
      read -p "Enter new SSH port (default 5250): " port
      port=${port:-}
      # Check if port is numeric and in valid range
      if ! [[ $port =~ ^[0-9]+$ ]] || ((port < 1024 || port > 65535)); then
         echo "Port must be a number between 1024 and 65535."
         continue
      fi
      # Check if port is reserved
      if [[ " ${reserved_ports[@]} " =~ " $port " ]]; then
         echo "Port $port is commonly used by popular services. Please choose another."
         continue
      fi
      # Check if port is already in use
      if ss -lnt | awk '{print $4}' | grep -q ":$port$"; then
         echo "Port $port is already in use on this host. Please choose another."
         continue
      fi
      break
   done
   NEW_SSH_PORT=$port
}

check_root() {
   if [[ $EUID -ne 0 ]]; then
      echo "This script must be run as root."
      exit 1
   fi
}

set_ssh_port() {
   echo "Configuring SSH to use port $NEW_SSH_PORT..."
   sed -i "s/^#Port 22/Port $NEW_SSH_PORT/" "$SSH_CONFIG"
}

disable_password_auth() {
   sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" "$SSH_CONFIG"
   sed -i "s/^PasswordAuthentication yes/PasswordAuthentication no/" "$SSH_CONFIG"
}

enable_pubkey_auth() {
   sed -i "s/^#PubkeyAuthentication yes/PubkeyAuthentication yes/" "$SSH_CONFIG"
}

restart_ssh_service() {
   systemctl restart ssh
}

show_completion_message() {
   echo "SSH configuration complete!"
   echo "Remember to open port $NEW_SSH_PORT in the firewall:"
   echo "    sudo ufw allow $NEW_SSH_PORT/tcp"
}

main() {
   check_root
   get_ssh_port
   set_ssh_port
   disable_password_auth
   enable_pubkey_auth
   restart_ssh_service
   show_completion_message
}

main
