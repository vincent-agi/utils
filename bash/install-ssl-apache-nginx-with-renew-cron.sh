#!/bin/bash

# Vérification des droits root
if [ "$(id -u)" -ne 0 ]; then
    echo "Ce script doit être exécuté en tant que root."
    exit 1
fi

# Vérification des paramètres
if [ -z "$1" ]; then
    echo "Usage : $0 <nom-de-domaine>"
    echo "Exemple : $0 exemple.com"
    exit 1
fi

DOMAIN=$1

# Fonction pour installer les dépendances nécessaires
install_dependencies() {
    echo "Mise à jour des paquets..."
    apt update && apt upgrade -y

    echo "Installation des dépendances..."
    apt install -y software-properties-common
    add-apt-repository -y universe
    apt update
}

# Fonction pour installer Certbot et son plugin pour Apache
install_certbot_apache() {
    echo "Installation de Certbot pour Apache..."
    apt install -y certbot python3-certbot-apache
    echo "Génération du certificat SSL pour $DOMAIN avec Apache..."
    certbot --apache -d "$DOMAIN" --non-interactive --agree-tos -m "admin@$DOMAIN"
}

# Fonction pour installer Certbot et son plugin pour Nginx
install_certbot_nginx() {
    echo "Installation de Certbot pour Nginx..."
    apt install -y certbot python3-certbot-nginx
    echo "Génération du certificat SSL pour $DOMAIN avec Nginx..."
    certbot --nginx -d "$DOMAIN" --non-interactive --agree-tos -m "admin@$DOMAIN"
}

# Fonction pour configurer le renouvellement automatique
configure_auto_renewal() {
    echo "Configuration du renouvellement automatique..."
    if ! crontab -l | grep -q "certbot renew"; then
        (crontab -l; echo "0 3 * * * certbot renew --quiet") | crontab -
    fi
}

# Menu de choix du serveur web
echo "Quel serveur web utilisez-vous ?"
echo "1) Apache"
echo "2) Nginx"
read -rp "Choisissez une option (1 ou 2) : " SERVER_CHOICE

# Installer Certbot et générer le certificat en fonction du choix
install_dependencies
case $SERVER_CHOICE in
    1)
        install_certbot_apache
        ;;
    2)
        install_certbot_nginx
        ;;
    *)
        echo "Choix invalide. Veuillez relancer le script et sélectionner 1 ou 2."
        exit 1
        ;;
esac

# Configurer le renouvellement automatique
configure_auto_renewal

echo "Certificat SSL installé et configuré avec succès pour $DOMAIN."
echo "Vous pouvez maintenant vérifier en accédant à https://$DOMAIN"