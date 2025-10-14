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
    PHP_MEMORY_LIMIT=2048M \
    PHP_MAX_EXECUTION_TIME=3600 \
    PHP_UPLOAD_LIMIT=2048M \
    OPCACHE_MEMORY_CONSUMPTION=256 \
    APACHE_RUN_USER=www-data \
    APACHE_RUN_GROUP=www-data \
    HOME=/var/www/html \
    DEBIAN_FRONTEND=noninteractive

# Installation des dépendances système
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    apache2 \
    software-properties-common \
    ca-certificates \
    curl \
    git \
    unzip \
    sudo \
    && add-apt-repository ppa:ondrej/php -y \
    && apt-get update && \
    apt-get install -y --no-install-recommends \
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
    libmagickcore-6.q16-7-extra \
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
    php /tmp/composer-setup.php --install-dir=/usr/local/bin --filename=composer --2.2 && \
    rm /tmp/composer-setup.php

# Configuration PHP pour Omni365
RUN echo "memory_limit = ${PHP_MEMORY_LIMIT}" > /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "upload_max_filesize = ${PHP_UPLOAD_LIMIT}" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "post_max_size = ${PHP_UPLOAD_LIMIT}" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "max_execution_time = ${PHP_MAX_EXECUTION_TIME}" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "max_input_time = 600" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "max_input_vars = 1000" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "date.timezone = UTC" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.enable = 1" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.interned_strings_buffer = 16" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.max_accelerated_files = 20000" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.memory_consumption = ${OPCACHE_MEMORY_CONSUMPTION}" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.revalidate_freq = 1" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "opcache.save_comments = 1" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini && \
    echo "apc.enable_cli=1" >> /etc/php/8.3/apache2/conf.d/99-nextcloud.ini

# Même configuration pour PHP CLI
RUN echo "memory_limit = ${PHP_MEMORY_LIMIT}" > /etc/php/8.3/cli/conf.d/99-nextcloud.ini && \
    echo "date.timezone = UTC" >> /etc/php/8.3/cli/conf.d/99-nextcloud.ini && \
    echo "opcache.enable_cli = 1" >> /etc/php/8.3/cli/conf.d/99-nextcloud.ini && \
    echo "apc.enable_cli=1" >> /etc/php/8.3/cli/conf.d/99-nextcloud.ini

# Création de la structure de répertoires
RUN mkdir -p /var/www/html && \
    chown -R www-data:www-data /var/www

# Clonage de Omni365 avec retry et gestion des erreurs
RUN echo "📥 Clonage du repository Omni365..." && \
    cd /var/www && \
    # Essayer plusieurs fois en cas d'échec réseau
    for i in 1 2 3 4 5; do \
        echo "Tentative $i de clonage..." && \
        git clone --depth 1 --branch ${NEXTCLOUD_VERSION} https://github.com/heritage-africa/omni365.git html-temp && \
        break || \
        (echo "Échec de la tentative $i, nouvel essai dans 10s..." && rm -rf html-temp && sleep 10); \
    done && \
    # Vérifier si le clonage a réussi
    if [ ! -d "html-temp" ]; then \
        echo "❌ Échec du clonage après 5 tentatives"; \
        exit 1; \
    fi && \
    mv html-temp/. html/ && \
    rm -rf html-temp && \
    chown -R www-data:www-data /var/www/html

# Installation des dépendances Composer
RUN echo "📦 Installation des dépendances Composer..." && \
    cd /var/www/html && \
    sudo -u www-data composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

# Installation des applications
RUN echo "📱 Installation des applications..." && \
    cd /var/www/html/apps && \
    # Application Activity
    sudo -u www-data git clone --branch v31.0.7 --depth 1 https://github.com/nextcloud/activity.git && \
    cd activity && \
    sudo -u www-data composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist && \
    cd .. && \
    # Application Notifications
    sudo -u www-data git clone --branch v31.0.7 --depth 1 https://github.com/nextcloud/notifications.git && \
    cd notifications && \
    sudo -u www-data composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist && \
    cd .. && \
    # Application Mail
    sudo -u www-data git clone --branch omni365-mail-v5.3.3 --depth 1 https://github.com/heritage-africa/omni365-mail.git mail && \
    cd mail && \
    sudo -u www-data composer install --no-dev --optimize-autoloader --no-interaction --prefer-dist

# Configuration Apache
RUN a2enmod rewrite headers env dir mime && \
    sed -i 's/Listen 80/Listen 8080/' /etc/apache2/ports.conf && \
    sed -i 's/<VirtualHost \*:80>/<VirtualHost \*:8080>/' /etc/apache2/sites-available/000-default.conf && \
    echo "ServerName localhost" >> /etc/apache2/apache2.conf && \
    echo "ServerTokens Prod" >> /etc/apache2/apache2.conf && \
    echo "ServerSignature Off" >> /etc/apache2/apache2.conf

# VirtualHost Omni365 personnalisé
COPY omni365-vhost.conf /etc/apache2/sites-available/nextcloud.conf
RUN a2ensite nextcloud.conf && a2dissite 000-default.conf

# Création des répertoires nécessaires
RUN mkdir -p /var/www/html/data /var/www/html/config /var/www/html/apps2 /var/www/sessions && \
    chown -R www-data:www-data /var/www/html /var/www/sessions && \
    chmod -R 750 /var/www/html/config /var/www/html/data && \
    chmod -R 755 /var/www/html/apps2 && \
    chmod -R 770 /var/www/sessions

# Configuration du session path pour PHP
RUN for version in cli apache2; do \
        if [ -f "/etc/php/8.3/${version}/php.ini" ]; then \
            sed -i 's|^;session.save_path = "/tmp"|session.save_path = "/var/www/sessions"|' /etc/php/8.3/${version}/php.ini; \
        fi; \
    done

# Nettoyage final
RUN apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* /var/www/html/.git

# Script d'initialisation
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Exposition des ports
EXPOSE 8080

WORKDIR /var/www/html

ENTRYPOINT ["/entrypoint.sh"]
CMD ["apache2ctl", "-D", "FOREGROUND"]
