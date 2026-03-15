#!/bin/bash

# Définition des variables
SSH_CONFIG="/etc/ssh/sshd_config"
NEW_SSH_PORT=5250

# Vérifier si l'utilisateur est root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root." 
   exit 1
fi

echo "Configuration de SSH sur le port $NEW_SSH_PORT..."

# Modifier le port SSH
sed -i "s/^#Port 22/Port $NEW_SSH_PORT/" $SSH_CONFIG

# Désactiver l'authentification par mot de passe
sed -i "s/^#PasswordAuthentication yes/PasswordAuthentication no/" $SSH_CONFIG
sed -i "s/^PasswordAuthentication yes/PasswordAuthentication no/" $SSH_CONFIG

# Activer l'authentification par clé SSH
sed -i "s/^#PubkeyAuthentication yes/PubkeyAuthentication yes/" $SSH_CONFIG

# Redémarrer le service SSH
systemctl restart ssh

echo "✅ Configuration terminée !"
echo "⚠️ Pense à ouvrir le port $NEW_SSH_PORT dans le firewall :"
echo "    sudo ufw allow $NEW_SSH_PORT/tcp"
