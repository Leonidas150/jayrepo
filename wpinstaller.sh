#!/bin/bash
# OpenLiteSpeed WordPress Manager Script
# This script will assist in managing WordPress installations on OpenLiteSpeed.

set -e

# Function to install WordPress
install_wordpress() {
    local domain=$1
    local db_name=$2
    local db_user=$3
    local db_pass=$4

    echo "Installing WordPress for domain ${domain}..."
    # Download WordPress
    wget https://wordpress.org/latest.tar.gz
    tar xzvf latest.tar.gz
    cp -R wordpress/* /var/www/${domain}/html/

    # Create wp-config.php
    cp /var/www/${domain}/html/wp-config-sample.php /var/www/${domain}/html/wp-config.php
    sed -i "s/database_name_here/${db_name}/" /var/www/${domain}/html/wp-config.php
    sed -i "s/username_here/${db_user}/" /var/www/${domain}/html/wp-config.php
    sed -i "s/password_here/${db_pass}/" /var/www/${domain}/html/wp-config.php

    echo "WordPress installed successfully for ${domain}!"
}

# Function to update WordPress
update_wordpress() {
    local domain=$1

    echo "Updating WordPress for domain ${domain}..."
    cd /var/www/${domain}/html
    wget https://wordpress.org/latest.tar.gz
    tar xzvf latest.tar.gz --strip-components=1

    echo "WordPress updated successfully for ${domain}!"
}

# Main script logic
if [[ "$1" == "install" ]]; then
    install_wordpress "$2" "$3" "$4" "$5"
elif [[ "$1" == "update" ]]; then
    update_wordpress "$2"
else
    echo "Usage: $0 [install|update] [domain] [db_name] [db_user] [db_pass]"
fi
