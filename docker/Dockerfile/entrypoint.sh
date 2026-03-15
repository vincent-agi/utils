## Fichier entrypoint.sh

#!/bin/bash

# Créer les dossiers nécessaires pour Certbot
mkdir -p /var/www/certbot

# Lancer NGINX en arrière-plan
nginx &

# Demander un certificat SSL via Certbot
certbot certonly --webroot -w /var/www/certbot -d yourdomain.com -d www.yourdomain.com --agree-tos --email your-email@example.com --non-interactive

# Lancer NGINX en mode frontal
nginx -s reload

# Garder le conteneur actif
tail -f /var/log/nginx/access.log
