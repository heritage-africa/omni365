#!/bin/bash
set -e

echo "🚀 Démarrage de Omni365..."

# Configuration des permissions au démarrage
mkdir -p /var/www/html/data /var/www/html/config /var/www/html/apps2
mkdir -p /var/log/apache2 /var/run/apache2 /var/www/sessions

# Configuration des permissions
chown -R www-data:www-data /var/www/html/data /var/www/html/config /var/www/html/apps2
chown -R www-data:www-data /var/log/apache2
chown -R www-data:www-data /var/www/sessions
chmod -R 750 /var/www/html/data /var/www/html/config
chmod -R 755 /var/www/html/apps2
chmod -R 755 /var/log/apache2
chmod -R 770 /var/www/sessions

# Configuration de PHP pour utiliser notre dossier sessions personnalisé
if [ -f "/etc/php/8.3/cli/php.ini" ]; then
    sed -i 's|^;session.save_path = "/tmp"|session.save_path = "/var/www/sessions"|' /etc/php/8.3/cli/php.ini
fi

if [ -f "/etc/php/8.3/apache2/php.ini" ]; then
    sed -i 's|^;session.save_path = "/tmp"|session.save_path = "/var/www/sessions"|' /etc/php/8.3/apache2/php.ini
fi

# Vérification et activation des applications si nécessaire
if [ -f "/var/www/html/occ" ]; then
    echo "🔧 Vérification des applications Nextcloud..."
    # Vérifier si l'app notifications est installée
    if [ -d "/var/www/html/apps/notifications" ]; then
        echo "✅ Application Notifications installée"
        # Activer l'app notifications si ce n'est pas déjà fait
        sudo -u www-data php /var/www/html/occ app:enable notifications || true
    else
        echo "⚠️  Application Notifications non trouvée"
    fi
fi

# Vérification des configurations critiques
if [ ! -f /var/www/html/config/config.php ] && [ -f /var/www/html/config/.ocdata ]; then
    echo "⚠️  Omni365 n'est pas configuré. Veuillez compléter l'installation via l'interface web."
fi

# Démarrage d'Apache
echo "✅ Configuration terminée, démarrage d'Apache..."
exec "$@"
