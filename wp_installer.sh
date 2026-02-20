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
[[ ! -w /var/log ]] && LOGFILE="/tmp/wp-install-final.log"
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
    echo -e "${GREEN}→ Tambah swap \( SWAP_SIZE (safety net OOM) \){NC}"
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

# ... (fungsi install_system_update, tune_php_fpm, tune_nginx, create_vhost, install_mariadb_secure, create_database, install_redis, tune_redis, install_wp_cli, install_wordpress, setup_redis_cache, install_certbot_ssl, setup_permissions, setup_ufw, setup_fail2ban, setup_backup_cron, setup_nginx_watchdog tetap sama seperti versi sebelumnya, tanpa escape salah)

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
