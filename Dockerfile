FROM ubuntu:noble

ARG NEXTCLOUD_VERSION=omni-v31.0.7

# Métadonnées
LABEL name="Omni365" \
      vendor="Omni365" \
      version="${NEXTCLOUD_VERSION}" \
      release="1" \
      summary="Omni365 production image" \
      description="Omni365 server optimized for deployment"

# Variables d'environnement
ENV NEXTCLOUD_VERSION=${NEXTCLOUD_VERSION} \
    PHP_MEMORY_LIMIT=20480M \
    PHP_MAX_EXECUTION_TIME=1200 \
    PHP_UPLOAD_LIMIT=20480M \
    OPCACHE_MEMORY_CONSUMPTION=512 \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    HOME=/var/www/html \
    DEBIAN_FRONTEND=noninteractive \
    # Variables PostgreSQL importantes
    POSTGRES_HOST=localhost \
    POSTGRES_USER=omni365 \
    POSTGRES_PASSWORD=omni365 \
    POSTGRES_DB=omni365db

# Installation des dépendances système - AJOUT des paquets PostgreSQL
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    apache2 \
    php8.3 \
    php8.3-common \
    php8.3-gd \
    php8.3-zip \
    php8.3-curl \
    php8.3-xml \
    php8.3-mbstring \
    php8.3-sqlite3 \
    php8.3-pgsql \
    php8.3-intl \
    php8.3-imagick \
    php8.3-gmp \
    php8.3-bcmath \
    php8.3-redis \
    php8.3-soap \
    php8.3-imap \
    php8.3-opcache \
    php8.3-cli \
    php8.3-mysql \
    php8.3-ldap \
    php8.3-apcu \
    libapache2-mod-php8.3 \
    git \
    curl \
    unzip \
    ca-certificates \
    libmagickcore-6.q16-7-extra \
    sudo \
    postgresql-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Configuration Git pour les gros repositories
RUN git config --global http.postBuffer 1048576000 && \
    git config --global core.compression 9 && \
    git config --global http.lowSpeedLimit 0 && \
    git config --global http.lowSpeedTime 999999

# Installation de Composer
RUN curl -sS https://getcomposer.org/installer -o /tmp/composer-setup.php && \
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer && \
    rm /tmp/composer-setup.php

# Installation de php-pear et pecl si nécessaire pour d'autres extensions
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    php8.3-dev \
    pkg-config \
    libssl-dev \
    php-pear \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Activation des extensions APCu et Redis (déjà installées via les paquets)
RUN phpenmod apcu redis

# Configuration PHP pour Omni365 - AJOUT de la configuration PostgreSQL
RUN echo "memory_limit = ${PHP_MEMORY_LIMIT}" > /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "upload_max_filesize = ${PHP_UPLOAD_LIMIT}" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "post_max_size = ${PHP_UPLOAD_LIMIT}" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "max_execution_time = 1200" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "max_input_time = 1200" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "date.timezone = UTC" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.enable = 1" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.interned_strings_buffer = 16" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.max_accelerated_files = 20000" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.memory_consumption = ${OPCACHE_MEMORY_CONSUMPTION}" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.revalidate_freq = 1" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "apc.enable_cli=1" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    # Configuration pour PostgreSQL
    echo "pdo_pgsql.default_socket=" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "pgsql.ignore_notice=0" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "pgsql.log_notice=0" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini

# Même configuration pour PHP CLI
RUN echo "memory_limit = ${PHP_MEMORY_LIMIT}" > /etc/php/8.3/cli/conf.d/99-nextcloud.ini && \
    echo "date.timezone = UTC" >> /etc/php/8.3/cli/conf.d/99-nextcloud.ini && \
    echo "opcache.enable_cli = 1" >> /etc/php/8.3/cli/conf.d/99-nextcloud.ini && \
    echo "apc.enable_cli=1" >> /etc/php/8.3/cli/conf.d/99-nextcloud.ini && \
    # Configuration PostgreSQL pour CLI
    echo "pdo_pgsql.default_socket=" >> /etc/php/8.3/cli/conf.d/99-nextcloud.ini && \
    echo "pgsql.ignore_notice=0" >> /etc/php/8.3/cli/conf.d/99-nextcloud.ini && \
    echo "pgsql.log_notice=0" >> /etc/php/8.3/cli/conf.d/99-nextcloud.ini

# Clonage de Omni365 avec retry et shallow clone
RUN echo "📥 Clonage du repository Omni365..." && \
    # Essayer plusieurs fois en cas d'échec réseau
    for i in 1 2 3 4 5; do \
        echo "Tentative $i..." && \
        git clone --depth 1 --branch ${NEXTCLOUD_VERSION} https://github.com/heritage-africa/omni365.git ${HOME}-temp && \
        break || \
        (echo "Échec de la tentative $i, nouvel essai dans 10s..." && sleep 10); \
    done && \
    cd ${HOME}-temp && \
    # Récupérer l'historique complet si nécessaire
    git fetch --unshallow || true && \
    cd .. && \
    cp -r ${HOME}-temp/. ${HOME}/ && \
    rm -rf ${HOME}-temp && \
    # Initialisation des sous-modules
    cd ${HOME} && \
    git submodule update --init --recursive --depth 1

# Installation des dépendances Composer
RUN cd ${HOME} && \
    composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

# Installation de l'application Activity avec la bonne branche
RUN echo "📱 Installation de l'application Activity..." && \
    cd ${HOME}/apps && \
    # Cloner avec la branche spécifique v31.0.7
    git clone --branch v31.0.7 --depth 1 https://github.com/nextcloud/activity.git && \
    cd activity && \
    # Installation des dépendances de l'app activity
    if [ -f "composer.json" ]; then \
        composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist; \
    fi && \
    echo "✅ Activity v31.0.7 installée avec succès"

# Installation de l'application Notifications avec la bonne branche
RUN echo "📱 Installation de l'application Notifications..." && \
    cd ${HOME}/apps && \
    # Cloner avec la branche spécifique v31.0.7
    git clone --branch v31.0.7 --depth 1 https://github.com/nextcloud/notifications.git && \
    cd notifications && \
    # Installation des dépendances de l'app notifications
    if [ -f "composer.json" ]; then \
        composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist; \
    fi && \
    echo "✅ Notifications v31.0.7 installée avec succès"


# Nettoyage
RUN rm -rf /tmp/* /var/tmp/* ${HOME}/.cache ${HOME}/.git

# Configuration Apache - corrections pour les permissions
RUN a2enmod rewrite headers env dir mime && \
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf && \
    sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf && \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    echo "ServerTokens Prod" >> /etc/apache2/apache2.conf && \
    echo "ServerSignature Off" >> /etc/apache2/apache2.conf && \
    # Configuration des logs pour écrire vers stdout/stderr
    ln -sf /dev/stdout /var/log/apache2/access.log && \
    ln -sf /dev/stderr /var/log/apache2/error.log && \
    # Configuration du PID file pour un emplacement accessible
    sed -i 's|^\(PIDFile\)|#\1|' /etc/apache2/apache2.conf && \
    echo "PidFile /tmp/apache2.pid" >> /etc/apache2/apache2.conf

# VirtualHost Omni365 personnalisé
COPY omni365-vhost.conf /etc/apache2/sites-available/nextcloud.conf
RUN a2ensite nextcloud.conf && a2dissite 000-default.conf

# Création des répertoires manquants et configuration des permissions
RUN mkdir -p ${HOME}/data ${HOME}/config ${HOME}/apps2 && \
    chown -R www-data:www-data ${HOME} && \
    chmod -R 755 ${HOME} && \
    chmod -R 750 ${HOME}/config && \
    chmod -R 750 ${HOME}/data && \
    # Création d'un dossier sessions personnalisé (pas /tmp système)
    mkdir -p /var/www/sessions && \
    chown -R www-data:www-data /var/www/sessions && \
    chmod -R 770 /var/www/sessions && \
    # Création des dossiers de logs avec permissions appropriées
    mkdir -p /var/log/apache2 && \
    chown -R www-data:www-data /var/www/sessions && \
    chmod -R 755 /var/log/apache2

# Nettoyage des paquets de développement (optionnel)
RUN apt-get remove -y php8.3-dev pkg-config libssl-dev php-pear && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Script d'initialisation
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Exposition des ports
EXPOSE 8080

# Volume pour les données persistantes
#VOLUME ["/var/www/html/data", "/var/www/html/config", "/var/www/html/apps2"]

# Utilisateur root pour éviter les problèmes de permissions
# USER www-data  <-- NE PAS utiliser www-data

WORKDIR ${HOME}

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]
