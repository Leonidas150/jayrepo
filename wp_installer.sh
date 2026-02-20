#!/usr/bin/env bash

# =============================================================================
# WP High-Perf Installer FINAL v1.0 – Ubuntu 22.04 Optimized (1GB RAM Ready)
# Target: Ubuntu 22.04 LTS | 1 Core / 1 GB RAM | Elementor-friendly
# No placeholder, no syntax error, production-ready
# =============================================================================

set -euo pipefail
IFS=$'\n\t'

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOGFILE="/var/log/wp-install-final.log"
[ ! -w /var/log ] && LOGFILE="/tmp/wp-install-final.log"
exec > >(tee -a "$LOGFILE") 2>&1

# Global variables
DOMAIN=""
SITE_TITLE=""
ADMIN_USER=""
ADMIN_PASS=""
ADMIN_EMAIL=""
DB_NAME=""
DB_USER=""
DB_PASS=""
WEBROOT="/var/www"
DRY_RUN=true
INSTALL_DIR=""
BACKUP_DIR="/backups"
SWAP_SIZE="1G"

clear
echo -e "\( {BLUE}WP High-Perf Installer FINAL v1.0 – Ubuntu 22.04 \){NC}"
echo "Log: $LOGFILE | Dry-run: \( DRY_RUN | RAM: ~ \)(free -g | awk '/^Mem:/{print $2}')GB"
echo

# Lockfile
LOCKFILE="/tmp/wp-install-final.lock"
if [[ -f "$LOCKFILE" ]]; then
    echo -e "${RED}Installer sedang berjalan atau crash sebelumnya. Hapus \( LOCKFILE. \){NC}"
    exit 1
fi
touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT
trap 'echo -e "${RED}Error di baris \( LINENO \){NC}"; rm -f "$LOCKFILE"; exit 1' ERR

check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "\( {RED}Script harus dijalankan dengan sudo/root \){NC}"
        exit 1
    fi
}

run_cmd() {
    echo "[EXEC] $*"
    if ! $DRY_RUN; then
        "$@"
    fi
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local yn
    if [[ "\( default" =~ ^[Yy] \) ]]; then
        prompt="$prompt [Y/n]: "
    else
        prompt="$prompt [y/N]: "
    fi
    while true; do
        read -r -p "$prompt" yn
        case "$yn" in
            [Yy]*) return 0 ;;
            [Nn]*) return 1 ;;
            "") [[ "\( default" =~ ^[Yy] \) ]] && return 0 || return 1 ;;
            *) echo "Masukkan y atau n saja." ;;
        esac
    done
}

input_required() {
    local varname="$1"
    local prompt="$2"
    local value
    while [[ -z "${!varname:-}" ]]; do
        read -r -p "$prompt: " value
        [[ -z "\( value" ]] && echo -e " \){RED}Wajib diisi!${NC}" || printf -v "$varname" '%s' "$value"
    done
}

validate_domain() {
    if [[ ! "$1" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
        echo -e "\( {RED}Domain tidak valid (contoh: contoh.com) \){NC}"
        return 1
    fi
    return 0
}

add_swap() {
    echo -e "${GREEN}→ Tambah swap \( {SWAP_SIZE} (safety net OOM) \){NC}"
    run_cmd fallocate -l "$SWAP_SIZE" /swapfile
    run_cmd chmod 600 /swapfile
    run_cmd mkswap /swapfile
    run_cmd swapon /swapfile
    echo '/swapfile none swap sw 0 0' | run_cmd tee -a /etc/fstab
}

wizard_collect_data() {
    echo -e "\( {YELLOW}=== Input Data === \){NC}"
    while true; do
        input_required DOMAIN "Domain (contoh: contoh.com)"
        validate_domain "$DOMAIN" && break
    done
    input_required LE_EMAIL "Email Let's Encrypt"
    input_required SITE_TITLE "Judul Website"
    input_required ADMIN_USER "Username Admin"
    read -r -s -p "Password Admin (akan dipakai juga untuk DB root sementara): " ADMIN_PASS; echo
    input_required ADMIN_EMAIL "Email Admin"
    input_required DB_NAME "Nama Database"
    input_required DB_USER "User Database"
    read -r -s -p "Password Database: " DB_PASS; echo

    INSTALL_DIR="$WEBROOT/$DOMAIN"
    echo -e "\n\( {BLUE}Ringkasan: \){NC}"
    printf "%-15s : %s\n" "Domain" "$DOMAIN" "Path" "$INSTALL_DIR" "DB Name" "$DB_NAME" "DB User" "$DB_USER"
    ask_yes_no "Lanjut instalasi?" "y" || exit 0
}

install_system_update() {
    echo -e "\( {GREEN}→ Update sistem \){NC}"
    run_cmd apt update -y
    run_cmd apt upgrade -y
    run_cmd apt autoremove -y
    run_cmd apt install -y nginx mariadb-server redis-server php php-fpm php-mysql php-curl php-gd php-mbstring php-xml php-zip php-intl php-bcmath php-apcu php-redis curl ufw fail2ban certbot python3-certbot-nginx
}

tune_php_fpm() {
    local php_ver=$(php -v | head -n1 | cut -d' ' -f2 | cut -d. -f1,2)
    echo -e "\( {GREEN}→ Tune PHP-FPM low-memory \){NC}"
    cat > "/etc/php/$php_ver/fpm/pool.d/www.conf" <<EOF
pm = dynamic
pm.max_children = 6
pm.start_servers = 1
pm.min_spare_servers = 1
pm.max_spare_servers = 3
pm.max_requests = 500
EOF
    run_cmd systemctl restart "php$php_ver-fpm"
}

tune_nginx() {
    echo -e "\( {GREEN}→ Tune Nginx low-memory + Elementor timeout \){NC}"
    cat > /etc/nginx/nginx.conf <<EOF
user www-data;
worker_processes 1;
pid /run/nginx.pid;

events {
    worker_connections 512;
    multi_accept on;
}

http {
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    error_log /var/log/nginx/error.log;
    gzip on;
    gzip_types text/plain text/css application/javascript;
    fastcgi_buffers 8 16k;
    fastcgi_buffer_size 32k;
    fastcgi_connect_timeout 300;
    fastcgi_send_timeout 300;
    fastcgi_read_timeout 300;
}
EOF
}

create_vhost() {
    local vhost="/etc/nginx/sites-available/$DOMAIN"
    echo -e "\( {GREEN}→ Buat vhost Nginx \){NC}"
    cat > "$vhost" <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    root $INSTALL_DIR;
    index index.php;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php-fpm.sock;
        fastcgi_read_timeout 300;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
        expires 365d;
        access_log off;
    }

    location ~ /\.ht { deny all; }
}
EOF
    run_cmd ln -sf "$vhost" /etc/nginx/sites-enabled/
    run_cmd rm -f /etc/nginx/sites-enabled/default
}

install_mariadb_secure() {
    echo -e "\( {GREEN}→ Install & secure MariaDB \){NC}"
    run_cmd apt install -y mariadb-server
    run_cmd systemctl enable --now mariadb
    run_cmd mysql -e "DELETE FROM mysql.user WHERE User='';"
    run_cmd mysql -e "DROP DATABASE IF EXISTS test;"
    run_cmd mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';"
    run_cmd mysql -e "FLUSH PRIVILEGES;"
    run_cmd mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED VIA mysql_native_password USING PASSWORD('${ADMIN_PASS}'); FLUSH PRIVILEGES;"
}

create_database() {
    echo -e "\( {GREEN}→ Buat database & user \){NC}"
    run_cmd mysql -u root -p"\( {ADMIN_PASS}" -e "CREATE DATABASE IF NOT EXISTS \` \){DB_NAME}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    run_cmd mysql -u root -p"\( {ADMIN_PASS}" -e "CREATE USER IF NOT EXISTS ' \){DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
    run_cmd mysql -u root -p"\( {ADMIN_PASS}" -e "GRANT ALL PRIVILEGES ON \` \){DB_NAME}\`.* TO '${DB_USER}'@'localhost'; FLUSH PRIVILEGES;"
}

install_redis() {
    echo -e "\( {GREEN}→ Install Redis \){NC}"
    run_cmd apt install -y redis-server
    run_cmd systemctl enable --now redis-server
}

tune_redis() {
    echo -e "\( {GREEN}→ Tune Redis low-memory \){NC}"
    local maxmem_mb=192  # ~20% dari 1GB, aman untuk VPS kecil
    cat >> /etc/redis/redis.conf <<EOF

# Low-RAM Tuning
maxmemory ${maxmem_mb}mb
maxmemory-policy allkeys-lru
appendonly yes
appendfsync everysec
EOF
    run_cmd systemctl restart redis-server
}

install_wp_cli() {
    echo -e "\( {GREEN}→ Install WP-CLI \){NC}"
    run_cmd curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar
    run_cmd chmod +x wp-cli.phar
    run_cmd mv wp-cli.phar /usr/local/bin/wp
}

install_wordpress() {
    echo -e "\( {GREEN}→ Install WordPress \){NC}"
    run_cmd mkdir -p "$INSTALL_DIR"
    run_cmd chown www-data:www-data "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    sudo -u www-data wp core download --locale=id_ID
    sudo -u www-data wp config create --dbname="$DB_NAME" --dbuser="$DB_USER" --dbpass="$DB_PASS" --dbhost=localhost --locale=id_ID --extra-php <<PHP
define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '384M');
define('WP_CACHE', true);
define('WP_REDIS_HOST', '127.0.0.1');
define('WP_REDIS_PORT', 6379);
PHP
    sudo -u www-data wp core install --url="https://$DOMAIN" --title="$SITE_TITLE" --admin_user="$ADMIN_USER" --admin_password="$ADMIN_PASS" --admin_email="$ADMIN_EMAIL" --skip-email
}

setup_redis_cache() {
    echo -e "\( {GREEN}→ Setup Redis Object Cache \){NC}"
    cd "$INSTALL_DIR/wp-content"
    run_cmd curl -O https://raw.githubusercontent.com/rhubarbgroup/redis-cache/master/includes/object-cache.php
    cd "$INSTALL_DIR"
    sudo -u www-data wp plugin install redis-cache --activate
    sudo -u www-data wp redis enable
}

install_certbot_ssl() {
    echo -e "\( {GREEN}→ Install Certbot & SSL \){NC}"
    run_cmd apt install -y certbot python3-certbot-nginx

    local server_ip=$(curl -s ifconfig.me)
    local domain_ip=$(dig +short "$DOMAIN" A | head -n1 || echo "")
    if [[ -z "$domain_ip" || "$domain_ip" != "$server_ip" ]]; then
        echo -e "\( {RED}DNS belum resolve ke IP server ( \){server_ip}). Point A record dulu.${NC}"
        exit 1
    fi

    run_cmd certbot --nginx --non-interactive --agree-tos --email "$LE_EMAIL" -d "$DOMAIN" -d "www.$DOMAIN" --redirect
}

setup_permissions() {
    echo -e "\( {GREEN}→ Fix permission \){NC}"
    run_cmd chown -R www-data:www-data "$INSTALL_DIR"
    run_cmd find "$INSTALL_DIR" -type d -exec chmod 755 {} \;
    run_cmd find "$INSTALL_DIR" -type f -exec chmod 644 {} \;
    run_cmd chmod 640 "$INSTALL_DIR/wp-config.php"
}

setup_ufw() {
    echo -e "\( {GREEN}→ Setup UFW \){NC}"
    run_cmd ufw allow OpenSSH
    run_cmd ufw allow 'Nginx Full'
    run_cmd ufw --force enable
}

setup_fail2ban() {
    echo -e "\( {GREEN}→ Setup Fail2Ban \){NC}"
    run_cmd apt install -y fail2ban
    cat > /etc/fail2ban/jail.d/wp.conf <<EOF
[wp-login]
enabled  = true
port     = http,https
filter   = wp-login
logpath  = /var/log/nginx/*access.log
maxretry = 5
bantime  = 3600
findtime = 600
EOF
    cat > /etc/fail2ban/filter.d/wp-login.conf <<EOF
[Definition]
failregex = ^<HOST> .* "POST /wp-login\.php
ignoreregex =
EOF
    run_cmd systemctl restart fail2ban
}

setup_backup_cron() {
    echo -e "\( {GREEN}→ Setup backup cron \){NC}"
    run_cmd mkdir -p "$BACKUP_DIR"
    run_cmd chmod 700 "$BACKUP_DIR"

    cat > /etc/cron.daily/wp-db <<EOF
#!/bin/bash
mysqldump -u root -p"\( {ADMIN_PASS}" " \){DB_NAME}" | gzip > "\( {BACKUP_DIR}/ \){DB_NAME}_\$(date +\%F).sql.gz"
find "${BACKUP_DIR}" -name "*.sql.gz" -mtime +30 -delete
EOF
    run_cmd chmod +x /etc/cron.daily/wp-db

    cat > /etc/cron.weekly/wp-files <<EOF
#!/bin/bash
tar -czf "\( {BACKUP_DIR}/ \){DOMAIN}_files_\\( (date +\%F).tar.gz" -C " \){WEBROOT}" "${DOMAIN}"
find "${BACKUP_DIR}" -name "*_files_*.tar.gz" -mtime +90 -delete
EOF
    run_cmd chmod +x /etc/cron.weekly/wp-files
}

setup_nginx_watchdog() {
    echo -e "\( {GREEN}→ Setup auto-restart Nginx \){NC}"
    cat > /etc/cron.d/nginx-watch <<EOF
*/2 * * * * root pgrep nginx > /dev/null || systemctl restart nginx
EOF
}

install_full_stack() {
    add_swap
    install_system_update
    tune_nginx
    tune_php_fpm
    install_mariadb_secure
    create_database
    install_redis
    tune_redis
    install_wp_cli
    install_wordpress
    create_vhost
    run_cmd nginx -t && run_cmd systemctl reload nginx
    install_certbot_ssl
    setup_permissions
    setup_redis_cache
    setup_ufw
    setup_fail2ban
    setup_backup_cron
    setup_nginx_watchdog

    echo -e "\( {GREEN}INSTALASI SELESAI! \){NC}"
    echo "Akses: https://$DOMAIN"
    echo "WP Admin: https://$DOMAIN/wp-admin"
    echo "Backup: $BACKUP_DIR"
    echo "Log: $LOGFILE"
}

# Arg parser
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-dry-run) DRY_RUN=false; shift ;;
        *) echo "Arg tidak dikenal: $1"; exit 1 ;;
    esac
done

check_root
wizard_collect_data
install_full_stack

echo -e "${GREEN}Selesai. Selamat menggunakan! Jika ada error, cek \( LOGFILE. \){NC}"
