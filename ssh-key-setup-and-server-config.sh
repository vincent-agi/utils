#!/bin/bash

LOGFILE="$HOME/ssh_setup_$(date +%Y%m%d_%H%M%S).log"

echo "==== Génération de la clé SSH ====" | tee -a $LOGFILE
read -p "Nom du fichier de la nouvelle clé (sans chemin, ex : id_monserveur) : " KEYNAME
KEYPATH="$HOME/.ssh/$KEYNAME"
if [[ -f "$KEYPATH" || -f "$KEYPATH.pub" ]]; then
    echo "Erreur : une clé existe déjà à ce nom ($KEYPATH). Annulation." | tee -a $LOGFILE
    exit 1
fi

read -p "Passphrase pour la clé (laisser vide pour aucune) : " -s KEYPASS
echo
ssh-keygen -t ed25519 -f "$KEYPATH" -N "$KEYPASS" | tee -a $LOGFILE
chmod 600 "$KEYPATH"
chmod 644 "$KEYPATH.pub"

echo "==== Ajout de la clé à l'agent SSH ====" | tee -a $LOGFILE
eval "$(ssh-agent -s)" | tee -a $LOGFILE
ssh-add "$KEYPATH" | tee -a $LOGFILE

echo "==== Informations de connexion serveur distant ====" | tee -a $LOGFILE
read -p "Adresse IP ou DNS du serveur distant : " REMOTE_HOST
read -p "Nom d'utilisateur distant (root ou sudoer) : " REMOTE_USER
read -p "Port SSH (défaut 22) : " REMOTE_PORT
REMOTE_PORT=${REMOTE_PORT:-22}

echo "==== Transfert de la clé publique sur le serveur ====" | tee -a $LOGFILE
ssh-copy-id -i "$KEYPATH.pub" -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" | tee -a $LOGFILE

echo "==== Vérification de la clé sur le serveur ====" | tee -a $LOGFILE
ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "grep \"$(cat $KEYPATH.pub | cut -d' ' -f2)\" ~/.ssh/authorized_keys" >/dev/null
if [[ $? -ne 0 ]]; then
    echo "Erreur : la clé ne semble pas présente sur le serveur. Annulation." | tee -a $LOGFILE
    exit 2
fi

echo "==== Mise à jour du fichier ~/.ssh/config ====" | tee -a $LOGFILE
SSH_CONFIG="$HOME/.ssh/config"
BACKUP_CONFIG="$SSH_CONFIG.bak.$(date +%Y%m%d_%H%M%S)"
if [[ -f "$SSH_CONFIG" ]]; then
    cp "$SSH_CONFIG" "$BACKUP_CONFIG"
    echo "Backup du fichier ssh_config dans $BACKUP_CONFIG" | tee -a $LOGFILE
else
    touch "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
fi

read -p "Nom du Host à utiliser dans ssh_config (ex: monserveur) : " SSH_HOST_ALIAS

# Vérifier si le Host existe déjà
if grep -q "Host $SSH_HOST_ALIAS" "$SSH_CONFIG"; then
    echo "Attention : une entrée Host $SSH_HOST_ALIAS existe déjà dans ssh_config." | tee -a $LOGFILE
    read -p "Remplacer l'entrée existante ? (O/n) " REPLACE
    if [[ "$REPLACE" != "O" && "$REPLACE" != "o" ]]; then
        echo "Annulation de la modif ssh_config." | tee -a $LOGFILE
    else
        # Supprimer l'ancienne entrée
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

echo "Entrée ajoutée à ssh_config :" | tee -a $LOGFILE
echo "Host $SSH_HOST_ALIAS
    HostName $REMOTE_HOST
    User $REMOTE_USER
    Port $REMOTE_PORT
    IdentityFile $KEYPATH
    IdentitiesOnly yes" | tee -a $LOGFILE

echo "==== Téléchargement et exécution du script distant ====" | tee -a $LOGFILE
SCRIPT_URL="https://raw.githubusercontent.com/vincent-agi/utils/refs/heads/main/bash/sshkey-config.sh"
SCRIPT_SHA256=$(curl -sSL $SCRIPT_URL | sha256sum | cut -d' ' -f1)
echo "SHA256 du script téléchargé : $SCRIPT_SHA256" | tee -a $LOGFILE

read -p "Souhaites-tu continuer et exécuter le script distant sur $REMOTE_HOST ? (o/N) : " CONFIRM
if [[ "$CONFIRM" != "o" && "$CONFIRM" != "O" ]]; then
    echo "Annulation à ta demande." | tee -a $LOGFILE
    exit 3
fi

ssh -p "$REMOTE_PORT" "$REMOTE_USER@$REMOTE_HOST" "curl -sSL $SCRIPT_URL | bash" | tee -a $LOGFILE

echo "==== Fin de la procédure ====" | tee -a $LOGFILE
echo "Toutes les actions ont été loguées dans $LOGFILE"
