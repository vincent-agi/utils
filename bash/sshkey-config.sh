#!/bin/bash

# Variables
USER="votre_utilisateur"
SERVER_IP="ip_du_serveur"

# Générer une clé SSH si elle n'existe pas
if [ ! -f ~/.ssh/id_ed25519 ]; then
    ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -q -N ""
    echo "Clé SSH générée."
else
    echo "Clé SSH existante."
fi

# Copier la clé publique sur le serveur
ssh-copy-id -i ~/.ssh/id_ed25519.pub $USER@$SERVER_IP

# Configurer le serveur SSH
ssh $USER@$SERVER_IP <<EOF
sudo sed -i 's/^#?PasswordAuthentication .*/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/^#?PubkeyAuthentication .*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/^#?PermitRootLogin .*/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
EOF

echo "Configuration SSH terminée. Testez la connexion avec : ssh $USER@$SERVER_IP"