#!/bin/bash
set -e

echo "🚀 Démarrage de Omni365..."

# Création des répertoires nécessaires pour les sessions
mkdir -p /var/www/sessions
chown -R www-data:www-data /var/www/sessions
chmod -R 770 /var/www/sessions

# Vérifier si /var/www/html est vide (premier démarrage avec volume vide)
if [ -z "$(ls -A /var/www/html)" ]; then
    echo "📂 Premier démarrage - Copie des fichiers Omni365..."
    
    # Copier le contenu depuis le répertoire temporaire
    cp -r /var/www/html-temp/. /var/www/html/
    
    # Configurer les permissions
    chown -R www-data:www-data /var/www/html
    chmod -R 750 /var/www/html/config
    chmod -R 750 /var/www/html/data
    chmod -R 755 /var/www/html/apps
    chmod -R 755 /var/www/html/apps2
    
    echo "✅ Fichiers Omni365 copiés avec succès"
else
    echo "📂 Répertoire /var/www/html contient déjà des données - pas de copie nécessaire"
    
    # Vérifier et corriger les permissions
    chown -R www-data:www-data /var/www/html
    find /var/www/html -type d -exec chmod 755 {} \;
    find /var/www/html -type f -exec chmod 644 {} \;
    chmod -R 750 /var/www/html/config 2>/dev/null || true
    chmod -R 750 /var/www/html/data 2>/dev/null || true
    chmod 750 /var/www/html/occ 2>/dev/null || true
fi

# Configuration des logs Apache
mkdir -p /var/log/apache2 /var/run/apache2
chown -R www-data:www-data /var/log/apache2 /var/run/apache2

# Vérification de la présence des applications
if [ -f "/var/www/html/occ" ]; then
    echo "🔧 Vérification des applications Nextcloud..."

    # Attendre que la base de données soit prête (si nécessaire)
    if [ -n "${POSTGRES_HOST}" ] && [ -n "${POSTGRES_USER}" ]; then
        echo "⏳ Attente de la base de données PostgreSQL..."
        until pg_isready -h "${POSTGRES_HOST}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -t 1; do
            echo "En attente de la base de données..."
            sleep 5
        done
    fi

    # Activer les applications si Nextcloud est configuré
    if [ -f "/var/www/html/config/config.php" ]; then
        APPS="activity notifications mail"

        for app in $APPS; do
            if [ -d "/var/www/html/apps/$app" ]; then
                echo "✅ Application $app installée - activation..."
                sudo -E -u www-data php /var/www/html/occ app:enable "$app" --no-interaction || echo "⚠️  Impossible d'activer $app (peut-être déjà activé)"
            else
                echo "⚠️  Application $app non trouvée dans /var/www/html/apps/"
            fi
        done

        # Exécuter les mises à jour
        echo "🔄 Vérification des mises à jour..."
        sudo -E -u www-data php /var/www/html/occ upgrade --no-interaction || true
    else
        echo "⚠️  Nextcloud non configuré. Les applications seront activées après la configuration initiale."
    fi
fi

# Démarrage d'Apache
echo "✅ Configuration terminée, démarrage d'Apache..."
exec "$@"
