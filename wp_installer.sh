#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

BASE="/opt/ols-manager"
SITES="$BASE/sites.db"
BACKUP="$BASE/backups"
OLS="/usr/local/lsws"
WWW="/var/www"

mkdir -p "$BASE" "$BACKUP"
touch "$SITES"

header() {
    clear
    echo "======================================"
    echo " OLS ENTERPRISE SERVER MANAGER"
    echo "======================================"
}

pause() {
    read -rp "Enter untuk lanjut..."
}

run() {
    echo "[EXEC] $*"
    "$@"
}

register_site() {
    read -rp "Domain: " domain
    read -rp "Path (ex: /var/www/site): " path
    echo "\( {domain}| \){path}" >> "$SITES"
    echo "Registered."
    pause
}

list_sites() {
    echo "=== Registered Sites ==="
    nl -w2 -s') ' "$SITES" || true
    pause
}

install_site() {
    read -rp "Domain: " domain
    read -rp "DB Name: " db
    read -rp "DB User: " dbu
    read -rsp "DB Pass: " dbp; echo

    path="$WWW/$domain"

    run mkdir -p "$path"
    run chown www-data:www-data "$path"

    # Download & extract WP
    cd "$WWW"
    run wget https://wordpress.org/latest.tar.gz
    run tar xf latest.tar.gz
    run mv wordpress/* "$path"/
    run rm -rf wordpress latest.tar.gz

    # DB setup (asumsi root pakai socket, kalau pakai password ganti ke -p"$PASS")
    run mysql -e "CREATE DATABASE IF NOT EXISTS $db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    run mysql -e "CREATE USER IF NOT EXISTS '$dbu'@'localhost' IDENTIFIED BY '$dbp';"
    run mysql -e "GRANT ALL PRIVILEGES ON $db.* TO '$dbu'@'localhost'; FLUSH PRIVILEGES;"

    # wp-config
    run cp "$path/wp-config-sample.php" "$path/wp-config.php"
    run sed -i "s/database_name_here/$db/" "$path/wp-config.php"
    run sed -i "s/username_here/$dbu/" "$path/wp-config.php"
    run sed -i "s/password_here/$dbp/" "$path/wp-config.php"

    echo "\( {domain}| \){path}" >> "$SITES"
    echo "Site installed + registered."
    pause
}

backup_site() {
    nl "$SITES"
    read -rp "Select site number: " n
    line=\( (sed -n " \){n}p" "$SITES")

    domain=$(echo "$line" | cut -d'|' -f1)
    path=$(echo "$line" | cut -d'|' -f2)

    backup_dir="$BACKUP/\( domain/ \)(date +%Y-%m-%d)"
    run mkdir -p "$backup_dir"

    run tar czf "$backup_dir/files.tar.gz" -C "$WWW" "$domain"
    run mysqldump -u root "$db" > "$backup_dir/db.sql"  # Ganti $db kalau perlu

    echo "Backup saved → $backup_dir"
    pause
}

restore_site() {
    read -rp "Backup folder path (ex: /opt/ols-manager/backups/domain/2025-02-20): " src
    read -rp "Restore to path: " dest

    run mkdir -p "$dest"
    run tar xzf "$src/files.tar.gz" -C "$dest"
    run mysql -u root < "$src/db.sql"

    echo "Restore done. Edit wp-config.php kalau DB/user/pass berubah."
    pause
}

bulk_update_wp() {
    while IFS= read -r line; do
        path=$(echo "$line" | cut -d'|' -f2)
        if [[ -d "$path" ]]; then
            run cd "$path"
            run wp core update --allow-root || true
            run wp plugin update --all --allow-root || true
            run wp theme update --all --allow-root || true
        fi
    done < "$SITES"
    pause
}

ssl_all() {
    while IFS= read -r line; do
        domain=$(echo "$line" | cut -d'|' -f1)
        path=$(echo "$line" | cut -d'|' -f2)
        run certbot certonly --webroot -w "$path" -d "$domain" --non-interactive --agree-tos -m "admin@$domain" || true
    done < "$SITES"
    pause
}

system_audit() {
    echo "===== SYSTEM AUDIT ====="
    echo "CPU:"; lscpu | grep "Model name"
    echo "RAM:"; free -h
    echo "Disk:"; df -h
    echo "Load:"; uptime
    echo "OLS Status:"; /usr/local/lsws/bin/lswsctrl status
    pause
}

php_switch() {
    apt search lsphp | grep lsphp
    read -rp "Install version (ex: lsphp83): " v
    run apt install -y "$v"
    run ln -sf "$OLS/$v/bin/php" /usr/bin/php
    run "$OLS/bin/lswsctrl restart"
    pause
}

snapshot() {
    snap="\( BACKUP/full_snapshot_ \)(date +%s)"
    run mkdir -p "$snap"
    run tar czf "$snap/ols.tar.gz" "$OLS"
    run tar czf "$snap/www.tar.gz" "$WWW"
    run mysqldump -u root --all-databases > "$snap/db.sql"
    echo "Snapshot ready → $snap"
    pause
}

cron_maintenance() {
    echo "Enabling auto maintenance..."
    (crontab -l 2>/dev/null; echo "0 3 * * * $0 --auto-update") | crontab -
    echo "Daily maintenance enabled."
    pause
}

auto_update() {
    while IFS= read -r line; do
        path=$(echo "$line" | cut -d'|' -f2)
        if [[ -d "$path" ]]; then
            cd "$path"
            wp core update --allow-root || true
            wp plugin update --all --allow-root || true
            wp theme update --all --allow-root || true
        fi
    done < "$SITES"
}

# Auto-update mode (untuk cron)
if [[ "${1:-}" == "--auto-update" ]]; then
    auto_update
    exit 0
fi

# Main menu loop
while true; do
    header
    echo "1) Install Site"
    echo "2) Register Existing Site"
    echo "3) List Sites"
    echo "4) Backup Site"
    echo "5) Restore Site"
    echo "6) Bulk Update WP"
    echo "7) Issue SSL All Sites"
    echo "8) PHP Switch"
    echo "9) System Audit"
    echo "10) Full Snapshot"
    echo "11) Enable Auto Maintenance"
    echo "0) Exit"
    echo

    read -rp "Select: " c

    case $c in
        1) install_site ;;
        2) register_site ;;
        3) list_sites ;;
        4) backup_site ;;
        5) restore_site ;;
        6) bulk_update_wp ;;
        7) ssl_all ;;
        8) php_switch ;;
        9) system_audit ;;
        10) snapshot ;;
        11) cron_maintenance ;;
        0) exit 0 ;;
        *) echo "Invalid choice"; sleep 1 ;;
    esac
done
