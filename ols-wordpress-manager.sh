#!/bin/bash

set -euo pipefail

################################################################################
# HEADER
################################################################################

SCRIPT_VERSION="2.0.0"
SCRIPT_NAME="OpenLiteSpeed WordPress Manager"
AUTHOR="DevOps Automation Team"
DEPLOYMENT_DATE="2026-02-20"

################################################################################
# VARIABLES
################################################################################

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="/var/log/ols-manager.log"
readonly REGISTRY_FILE="/etc/ols-manager/sites-registry.conf"
readonly BACKUP_DIR="/opt/ols-backups"
readonly TEMP_DIR="/tmp/ols-manager-$$"
readonly SITES_ROOT="/home/ols-sites"
readonly OLS_USER="nobody"
readonly OLS_GROUP="nogroup"

readonly UBUNTU_VERSION="$(lsb_release -rs | cut -d. -f1)"
readonly TIMESTAMP="$(date +%Y%m%d_%H%M%S)"

OLS_INSTALL_PATH="/usr/local/lsws"
LSPHP_VERSION=""
MARIADB_VERSION="10.11"
WORDPRESS_VERSION=""
DB_ROOT_PASS=""
ENABLE_SSL=0
PHP_VERSION="82"

BOLD='\033[1m'
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

################################################################################
# UTILITY FUNCTIONS
################################################################################

log_info() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${BLUE}[INFO]${NC} ${message}"
    echo "[${timestamp}] [INFO] ${message}" >> "${LOG_FILE}"
}

log_success() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${GREEN}[SUCCESS]${NC} ${message}"
    echo "[${timestamp}] [SUCCESS] ${message}" >> "${LOG_FILE}"
}

log_warning() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${YELLOW}[WARNING]${NC} ${message}"
    echo "[${timestamp}] [WARNING] ${message}" >> "${LOG_FILE}"
}

log_error() {
    local message="$1"
    local timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo -e "${RED}[ERROR]${NC} ${message}" >&2
    echo "[${timestamp}] [ERROR] ${message}" >> "${LOG_FILE}"
}

die() {
    local message="$1"
    local exit_code="${2:-1}"
    log_error "${message}"
    exit "${exit_code}"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root"
    fi
}

check_ubuntu_version() {
    if [[ "${UBUNTU_VERSION}" != "22" && "${UBUNTU_VERSION}" != "24" ]]; then
        die "Unsupported Ubuntu version. Requires 22.04 or 24.04"
    fi
    log_info "Detected Ubuntu ${UBUNTU_VERSION}.04"
}

initialize_logging() {
    local log_dir="$(dirname "${LOG_FILE}")"
    mkdir -p "${log_dir}"
    touch "${LOG_FILE}"
    chmod 644 "${LOG_FILE}"
    log_info "=== ${SCRIPT_NAME} v${SCRIPT_VERSION} Started ==="
}

validate_domain() {
    local domain="$1"
    local regex="^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$"
    
    if [[ ! "${domain}" =~ ${regex} ]]; then
        return 1
    fi
    return 0
}

validate_email() {
    local email="$1"
    local regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    
    if [[ ! "${email}" =~ ${regex} ]]; then
        return 1
    fi
    return 0
}

sanitize_input() {
    local input="$1"
    echo "${input}" | sed "s/[^a-zA-Z0-9._-]//g"
}

sanitize_db_name() {
    local input="$1"
    echo "${input}" | sed "s/[^a-zA-Z0-9_]//g" | cut -c1-64
}

sanitize_db_user() {
    local input="$1"
    echo "${input}" | sed "s/[^a-zA-Z0-9_]//g" | cut -c1-16
}

escape_sql() {
    local input="$1"
    printf '%s\n' "${input}" | sed -e "s/'/\\\\'/g"
}

generate_random_password() {
    local length="${1:-32}"
    openssl rand -base64 "${length}" | tr -d "=+/" | cut -c1-"${length}"
}

generate_wp_salts() {
    local salts=""
    local salt_keys=("AUTH_KEY" "SECURE_AUTH_KEY" "LOGGED_IN_KEY" "NONCE_KEY" 
                     "AUTH_SALT" "SECURE_AUTH_SALT" "LOGGED_IN_SALT" "NONCE_SALT")
    
    for key in "${salt_keys[@]}"; do
        local salt_value="$(openssl rand -base64 48 | tr -d '\n')"
        salts="${salts}define('${key}', '${salt_value}');\n"
    done
    
    echo -e "${salts}"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
    return $?
}

confirm() {
    local prompt="$1"
    local response
    
    read -p "$(echo -e "${YELLOW}${prompt}${NC} (y/n): ")" -n 1 -r response
    echo
    [[ "${response}" =~ ^[Yy]$ ]]
}

cleanup() {
    if [[ -d "${TEMP_DIR}" ]]; then
        rm -rf "${TEMP_DIR}"
    fi
}

trap cleanup EXIT

menu_pause() {
    read -p "Press ENTER to continue..."
}

################################################################################
# INSTALL FUNCTIONS
################################################################################

update_system_packages() {
    log_info "Updating system packages..."
    apt-get update || die "Failed to update package lists"
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y || die "Failed to upgrade packages"
    log_success "System packages updated"
}

install_dependencies() {
    log_info "Installing dependencies..."
    
    local packages=(
        "curl" "wget" "git" "nano" "vim" "htop" "net-tools"
        "build-essential" "libpcre3-dev" "zlib1g-dev"
        "ssl-cert" "certbot" "python3-certbot-apache"
        "ufw" "fail2ban" "openssl" "jq"
    )
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}" || die "Failed to install dependencies"
    log_success "Dependencies installed"
}

install_openlitespeed() {
    log_info "Installing OpenLiteSpeed..."
    
    if command_exists lshttpd; then
        log_warning "OpenLiteSpeed already installed"
        return 0
    fi
    
    local keyfile="/tmp/ols-repo-key.gpg"
    
    if ! wget -q -O "${keyfile}" https://repo.litespeedtech.com/release/litespeed-repo.gpg; then
        log_warning "Failed to download GPG key, continuing without verification"
    else
        apt-key add "${keyfile}" 2>/dev/null || true
        rm -f "${keyfile}"
    fi
    
    if [[ "${UBUNTU_VERSION}" == "24" ]]; then
        local repo_url="http://repo.litespeedtech.com/ubuntu jammy main"
    else
        local repo_url="http://repo.litespeedtech.com/ubuntu jammy main"
    fi
    
    echo "deb ${repo_url}" | tee /etc/apt/sources.list.d/openlitespeed.list >/dev/null
    
    apt-get update || log_warning "APT update partially failed"
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y openlitespeed || die "Failed to install OpenLiteSpeed"
    
    systemctl enable lsws || log_warning "Failed to enable LSWS service"
    log_success "OpenLiteSpeed installed"
}

install_lsphp() {
    log_info "Installing LiteSpeed PHP..."
    
    if [[ "${UBUNTU_VERSION}" == "24" ]]; then
        local lsphp_versions=("lsphp84" "lsphp83" "lsphp82")
    else
        local lsphp_versions=("lsphp82" "lsphp81" "lsphp80")
    fi
    
    for version in "${lsphp_versions[@]}"; do
        if apt-cache show "${version}" &>/dev/null; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y "${version}" || continue
            LSPHP_VERSION="${version}"
            log_success "Installed ${LSPHP_VERSION}"
            return 0
        fi
    done
    
    die "Failed to install any LiteSpeed PHP version"
}

install_php_extensions() {
    log_info "Installing PHP extensions..."
    
    if [[ -z "${LSPHP_VERSION}" ]]; then
        log_warning "LSPHP version not set, skipping extension installation"
        return 0
    fi
    
    local extensions=(
        "${LSPHP_VERSION}-mysql"
        "${LSPHP_VERSION}-curl"
        "${LSPHP_VERSION}-gd"
        "${LSPHP_VERSION}-mbstring"
        "${LSPHP_VERSION}-xml"
        "${LSPHP_VERSION}-zip"
        "${LSPHP_VERSION}-soap"
        "${LSPHP_VERSION}-intl"
    )
    
    for ext in "${extensions[@]}"; do
        if apt-cache show "${ext}" &>/dev/null; then
            DEBIAN_FRONTEND=noninteractive apt-get install -y "${ext}" || log_warning "Failed to install ${ext}"
        fi
    done
    
    log_success "PHP extensions installed"
}

install_mariadb() {
    log_info "Installing MariaDB..."
    
    if command_exists mysql; then
        log_warning "MariaDB already installed"
        return 0
    fi
    
    curl -fsSL https://mariadb.org/mariadb_release_signing_key.asc | gpg --dearmor > /usr/share/keyrings/mariadb-keyring.gpg 2>/dev/null || true
    
    if [[ "${UBUNTU_VERSION}" == "24" ]]; then
        echo "deb [signed-by=/usr/share/keyrings/mariadb-keyring.gpg] https://mirror.mariadb.org/repo/11.2/ubuntu noble main" | tee /etc/apt/sources.list.d/mariadb.list >/dev/null
        MARIADB_VERSION="11.2"
    else
        echo "deb [signed-by=/usr/share/keyrings/mariadb-keyring.gpg] https://mirror.mariadb.org/repo/10.11/ubuntu jammy main" | tee /etc/apt/sources.list.d/mariadb.list >/dev/null
        MARIADB_VERSION="10.11"
    fi
    
    apt-get update || log_warning "APT update partially failed"
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y mariadb-server || die "Failed to install MariaDB"
    
    systemctl enable mariadb || log_warning "Failed to enable MariaDB service"
    systemctl start mariadb || die "Failed to start MariaDB"
    
    log_success "MariaDB ${MARIADB_VERSION} installed"
}

secure_mariadb() {
    log_info "Securing MariaDB..."
    
    DB_ROOT_PASS="$(generate_random_password 32)"
    
    mysql -e "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_PASS}') WHERE User='root';" || log_warning "Failed to update root password"
    mysql -e "DELETE FROM mysql.user WHERE User='';" || log_warning "Failed to remove anonymous users"
    mysql -e "DELETE FROM mysql.db WHERE Db='test' OR Db='test\_%';" || log_warning "Failed to remove test databases"
    mysql -e "FLUSH PRIVILEGES;" || log_warning "Failed to flush privileges"
    
    mkdir -p /root/.mysql
    cat > /root/.mysql/credentials <<EOF
[client]
user = root
password = ${DB_ROOT_PASS}
EOF
    chmod 600 /root/.mysql/credentials
    
    log_success "MariaDB secured"
}

install_wordpress() {
    log_info "Downloading WordPress..."
    
    if [[ ! -d "${TEMP_DIR}" ]]; then
        mkdir -p "${TEMP_DIR}"
    fi
    
    cd "${TEMP_DIR}"
    
    if ! curl -fsSL https://wordpress.org/latest.tar.gz -o wordpress.tar.gz; then
        die "Failed to download WordPress"
    fi
    
    if ! tar -xzf wordpress.tar.gz; then
        die "Failed to extract WordPress"
    fi
    
    WORDPRESS_VERSION="$(grep "'WP_VERSION'" "${TEMP_DIR}/wordpress/wp-includes/version.php" | grep -oP "'\K[^']+(?=')" || echo "latest")"
    log_success "WordPress ${WORDPRESS_VERSION} downloaded"
}

configure_openlitespeed() {
    log_info "Configuring OpenLiteSpeed..."
    
    local config_file="${OLS_INSTALL_PATH}/conf/httpd_config.conf"
    
    if [[ ! -f "${config_file}" ]]; then
        log_warning "OpenLiteSpeed config not found, skipping advanced configuration"
        return 0
    fi
    
    cp "${config_file}" "${config_file}.backup.${TIMESTAMP}"
    
    cat >> "${config_file}" <<'EOFCONF'

<context /wp-admin>
  location                $SERVER_ROOT/wordpress/wp-admin/
  allowBrowse             0
  enableExpires            1
  expireTime              3600
</context>

<context /wp-content>
  location                $SERVER_ROOT/wordpress/wp-content/
  allowBrowse             1
  enableExpires            1
  expireTime              604800
</context>
EOFCONF
    
    log_success "OpenLiteSpeed configured"
}

optimize_php_ini() {
    log_info "Optimizing PHP configuration..."
    
    local php_conf_dir="${OLS_INSTALL_PATH}/lsphp${PHP_VERSION:0:2}/etc/php/${PHP_VERSION:0:1}.${PHP_VERSION:1:1}/litespeed/php.ini"
    
    if [[ ! -f "${php_conf_dir}" ]]; then
        php_conf_dir="/etc/php/${PHP_VERSION:0:1}.${PHP_VERSION:1:1}/litespeed/php.ini"
    fi
    
    if [[ ! -f "${php_conf_dir}" ]]; then
        log_warning "PHP configuration file not found at ${php_conf_dir}"
        return 0
    fi
    
    cp "${php_conf_dir}" "${php_conf_dir}.backup.${TIMESTAMP}"
    
    local php_settings=(
        "max_execution_time=300"
        "max_input_time=60"
        "memory_limit=256M"
        "post_max_size=64M"
        "upload_max_filesize=64M"
        "default_charset=UTF-8"
    )
    
    for setting in "${php_settings[@]}"; do
        local key="${setting%%=*}"
        local value="${setting#*=}"
        
        if grep -q "^${key}" "${php_conf_dir}"; then
            sed -i "s/^${key}[[:space:]]*=.*/sed -i \"s|^${key}[[:space:]]*=.*|${key} = ${value}|\" \"${php_conf_dir}\"" "${php_conf_dir}" || true
        else
            echo "${key} = ${value}" >> "${php_conf_dir}"
        fi
    done
    
    log_success "PHP optimized"
}

optimize_mariadb() {
    log_info "Optimizing MariaDB..."
    
    local mariadb_conf="/etc/mysql/mariadb.conf.d/99-ols-optimizations.cnf"
    
    cat > "${mariadb_conf}" <<'EOFDB'
[mysqld]
max_connections = 200
max_allowed_packet = 256M
innodb_buffer_pool_size = 1G
innodb_log_file_size = 256M
query_cache_size = 64M
query_cache_type = 1
thread_cache_size = 16
sort_buffer_size = 2M
bulk_insert_buffer_size = 16M
tmp_table_size = 32M
max_heap_table_size = 32M
EOFDB
    
    systemctl restart mariadb || log_warning "Failed to restart MariaDB"
    log_success "MariaDB optimized"
}

setup_firewall() {
    log_info "Configuring firewall..."
    
    systemctl enable ufw || log_warning "Failed to enable UFW"
    systemctl start ufw || log_warning "Failed to start UFW"
    
    ufw default deny incoming || log_warning "Failed to set UFW default policy"
    ufw default allow outgoing || log_warning "Failed to set UFW default policy"
    
    ufw allow 22/tcp || log_warning "Failed to allow SSH"
    ufw allow 80/tcp || log_warning "Failed to allow HTTP"
    ufw allow 443/tcp || log_warning "Failed to allow HTTPS"
    ufw allow 7080/tcp || log_warning "Failed to allow OpenLiteSpeed console"
    
    echo "y" | ufw enable || log_warning "Failed to enable UFW"
    
    log_success "Firewall configured"
}

setup_fail2ban() {
    log_info "Configuring Fail2Ban..."
    
    systemctl enable fail2ban || log_warning "Failed to enable Fail2Ban"
    systemctl start fail2ban || log_warning "Failed to start Fail2Ban"
    
    cat > /etc/fail2ban/jail.local <<'EOFAIL2BAN'
[DEFAULT]
ignoreip = 127.0.0.1/8
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = ssh

[recidive]
enabled = true
filter = recidive
action = iptables-multiport[name=Recidive, port="http,https"]
bantime = 86400
findtime = 86400
maxretry = 3
EOFAIL2BAN
    
    systemctl restart fail2ban || log_warning "Failed to restart Fail2Ban"
    log_success "Fail2Ban configured"
}

setup_directory_structure() {
    log_info "Setting up directory structure..."
    
    mkdir -p "${SITES_ROOT}"
    mkdir -p "${BACKUP_DIR}"
    mkdir -p "/etc/ols-manager"
    
    chmod 755 "${SITES_ROOT}"
    chmod 755 "${BACKUP_DIR}"
    chmod 755 "/etc/ols-manager"
    
    touch "${REGISTRY_FILE}"
    chmod 644 "${REGISTRY_FILE}"
    
    log_success "Directory structure created"
}

install_full_stack() {
    log_info "Starting full OpenLiteSpeed + WordPress installation"
    
    check_root
    check_ubuntu_version
    initialize_logging
    
    update_system_packages
    install_dependencies
    install_openlitespeed
    install_lsphp
    install_php_extensions
    install_mariadb
    secure_mariadb
    install_wordpress
    configure_openlitespeed
    optimize_php_ini
    optimize_mariadb
    setup_directory_structure
    setup_firewall
    setup_fail2ban
    
    log_success "Full stack installation completed"
}

################################################################################
# SITE FUNCTIONS
################################################################################

register_site() {
    local domain="$1"
    local app_path="${2:-.}"
    
    if grep -q "^${domain}:" "${REGISTRY_FILE}" 2>/dev/null; then
        log_warning "Site ${domain} already registered"
        return 1
    fi
    
    echo "${domain}:${app_path}:$(date +%s)" >> "${REGISTRY_FILE}"
    log_info "Site ${domain} registered at ${app_path}"
    return 0
}

is_site_registered() {
    local domain="$1"
    grep -q "^${domain}:" "${REGISTRY_FILE}" 2>/dev/null
}

get_site_path() {
    local domain="$1"
    grep "^${domain}:" "${REGISTRY_FILE}" 2>/dev/null | cut -d: -f2 | head -1
}

create_new_site() {
    echo -e "\n${BOLD}Create New Site${NC}"
    
    local domain=""
    while [[ -z "${domain}" ]] || ! validate_domain "${domain}"; do
        read -p "Enter domain name (e.g., example.com): " domain
        if ! validate_domain "${domain}"; then
            log_error "Invalid domain format"
            domain=""
        fi
    done
    
    if is_site_registered "${domain}"; then
        die "Domain ${domain} is already registered"
    fi
    
    local site_path="${SITES_ROOT}/${domain}"
    local db_name="$(sanitize_db_name "${domain//./_}")"
    local db_user="$(sanitize_db_user "${domain//./_:0:16}")"
    local db_pass="$(generate_random_password 32)"
    
    log_info "Creating site: ${domain}"
    log_info "Site path: ${site_path}"
    log_info "Database: ${db_name}"
    
    if [[ -d "${site_path}" ]]; then
        die "Site directory already exists at ${site_path}"
    fi
    
    mkdir -p "${site_path}"
    
    if [[ -d "${TEMP_DIR}/wordpress" ]]; then
        cp -r "${TEMP_DIR}/wordpress"/* "${site_path}/"
    fi
    
    generate_wp_config "${site_path}" "${db_name}" "${db_user}" "${db_pass}" "${domain}"
    
    create_mysql_database "${db_name}" "${db_user}" "${db_pass}"
    
    set_site_permissions "${site_path}"
    
    create_virtual_host "${domain}" "${site_path}"
    
    register_site "${domain}" "${site_path}"
    
    systemctl restart lsws || log_warning "Failed to restart OpenLiteSpeed"
    
    log_success "Site created successfully!"
    echo -e "\n${BOLD}Site Details:${NC}"
    echo "Domain: ${domain}"
    echo "Path: ${site_path}"
    echo "Database: ${db_name}"
    echo "Database User: ${db_user}"
    echo "Database Password: ${db_pass}"
    echo ""
}

generate_wp_config() {
    local site_path="$1"
    local db_name="$2"
    local db_user="$3"
    local db_pass="$4"
    local domain="$5"
    
    local wp_config="${site_path}/wp-config.php"
    
    if [[ -f "${wp_config}" ]]; then
        rm -f "${wp_config}"
    fi
    
    local salts="$(generate_wp_salts)"
    
    cat > "${wp_config}" <<EOFWPCONFIG
<?php
define('DB_NAME', '${db_name}');
define('DB_USER', '${db_user}');
define('DB_PASSWORD', '${db_pass}');
define('DB_HOST', 'localhost');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', 'utf8mb4_unicode_ci');

${salts}

define('WP_HOME', 'http${ENABLE_SSL:+s}://${domain}');
define('WP_SITEURL', 'http${ENABLE_SSL:+s}://${domain}');

define('WP_DEBUG', false);
define('WP_DEBUG_LOG', '${site_path}/wp-content/debug.log');
define('WP_DEBUG_DISPLAY', false);

define('DISALLOW_FILE_EDIT', true);
define('DISALLOW_FILE_MODS', true);
define('AUTOMATIC_UPDATER_DISABLED', true);

define('WP_MEMORY_LIMIT', '256M');
define('WP_MAX_MEMORY_LIMIT', '512M');

if (!isset(\$_SERVER['HTTPS']) || \$_SERVER['HTTPS'] !== 'on') {
    if (!empty(\$_SERVER['HTTP_CF_VISITOR'])) {
        \$cf_visitor = json_decode(\$_SERVER['HTTP_CF_VISITOR']);
        if (\$cf_visitor->scheme === 'https') {
            \$_SERVER['HTTPS'] = 'on';
        }
    }
}

if (\$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    \$_SERVER['HTTPS'] = 'on';
}

\$table_prefix = 'wp_';

if (!defined('ABSPATH')) {
    define('ABSPATH', dirname(__FILE__) . '/');
}

require_once(ABSPATH . 'wp-settings.php');
?>
EOFWPCONFIG
    
    log_info "wp-config.php generated for ${domain}"
}

create_mysql_database() {
    local db_name="$1"
    local db_user="$2"
    local db_pass="$3"
    
    log_info "Creating database ${db_name}..."
    
    local db_pass_escaped="$(escape_sql "${db_pass}")"
    
    mysql -e "CREATE DATABASE IF NOT EXISTS \`${db_name}\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || die "Failed to create database"
    mysql -e "CREATE USER IF NOT EXISTS '${db_user}'@'localhost' IDENTIFIED BY '${db_pass_escaped}';" || log_warning "User creation failed or user exists"
    mysql -e "GRANT ALL PRIVILEGES ON \`${db_name}\`.* TO '${db_user}'@'localhost';" || die "Failed to grant privileges"
    mysql -e "FLUSH PRIVILEGES;" || die "Failed to flush privileges"
    
    log_success "Database created and user configured"
}

set_site_permissions() {
    local site_path="$1"
    
    log_info "Setting permissions for ${site_path}..."
    
    chown -R nobody:nogroup "${site_path}"
    chmod -R 755 "${site_path}"
    chmod -R 775 "${site_path}/wp-content"
    chmod 644 "${site_path}/wp-config.php"
    chmod -R 755 "${site_path}/wp-admin"
    chmod -R 755 "${site_path}/wp-includes"
    
    find "${site_path}" -type f -exec chmod 644 {} \;
    find "${site_path}" -type d -exec chmod 755 {} \;
    
    log_success "Permissions configured"
}

create_virtual_host() {
    local domain="$1"
    local site_path="$2"
    
    log_info "Creating virtual host for ${domain}..."
    
    local vhost_conf_dir="${OLS_INSTALL_PATH}/conf/vhosts"
    local vhost_config="${vhost_conf_dir}/${domain}.conf"
    
    mkdir -p "${vhost_conf_dir}"
    
    cat > "${vhost_config}" <<EOFVHOST
virtualhost ${domain} {
  vhroot                  ${site_path}/
  configfile              \$SERVER_ROOT/conf/vhosts/${domain}/vhconf.conf
  allowSymbolLink         1
  enableScript            1
  restartable             0
  user                    nobody
  group                   nogroup
  staticContext {
    uri                   /
    location              \$VH_ROOT/
    allowBrowse           0
    enableExpires         1
    expireTime            3600
    contextType           static
  }
  scripthandler {
    add                   lsapi:{LSPHP_VERSION} php
  }
  scriptContext {
    uri                   *.php$
    location              \$VH_ROOT/
    handler               lsapi:{LSPHP_VERSION}
    addAllowedContext     1
  }
}
EOFVHOST
    
    mkdir -p "${vhost_conf_dir}/${domain}"
    
    cat > "${vhost_conf_dir}/${domain}/vhconf.conf" <<EOFVHCONF
enableGzip              1
enableBrotli            1
gzipCompTypes           text/* application/javascript application/json
staticContext {
  uri                   /
  location              \$VH_ROOT/
  allowBrowse           0
}
context {
  uri                   /wp-admin
  location              \$VH_ROOT/wp-admin/
  allowBrowse           0
}
context {
  uri                   /wp-content
  location              \$VH_ROOT/wp-content/
  allowBrowse           1
  enableExpires         1
  expireTime            604800
}
EOFVHCONF
    
    log_success "Virtual host created for ${domain}"
}

register_existing_site() {
    echo -e "\n${BOLD}Register Existing Site${NC}"
    
    local domain=""
    while [[ -z "${domain}" ]] || ! validate_domain "${domain}"; do
        read -p "Enter domain name: " domain
        if ! validate_domain "${domain}"; then
            log_error "Invalid domain format"
            domain=""
        fi
    done
    
    if is_site_registered "${domain}"; then
        log_warning "Domain already registered"
        return 1
    fi
    
    local site_path=""
    while [[ ! -d "${site_path}" ]]; do
        read -p "Enter site path (full path): " site_path
        if [[ ! -d "${site_path}" ]]; then
            log_error "Directory does not exist"
            site_path=""
        fi
    done
    
    if [[ ! -f "${site_path}/wp-config.php" ]]; then
        log_warning "wp-config.php not found in ${site_path}"
    fi
    
    register_site "${domain}" "${site_path}"
    
    set_site_permissions "${site_path}"
    
    create_virtual_host "${domain}" "${site_path}"
    
    systemctl restart lsws || log_warning "Failed to restart OpenLiteSpeed"
    
    log_success "Site registered successfully"
}

list_sites() {
    echo -e "\n${BOLD}Registered Sites${NC}\n"
    
    if [[ ! -f "${REGISTRY_FILE}" ]] || [[ ! -s "${REGISTRY_FILE}" ]]; then
        log_info "No sites registered"
        return 0
    fi
    
    while IFS=: read -r domain path timestamp; do
        local registered_date="$(date -d @${timestamp} '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'Unknown')"
        echo "Domain: ${domain}"
        echo "Path: ${path}"
        echo "Registered: ${registered_date}"
        echo "---"
    done < "${REGISTRY_FILE}"
}

################################################################################
# BACKUP FUNCTIONS
################################################################################

backup_site() {
    local domain="$1"
    
    if ! is_site_registered "${domain}"; then
        log_error "Site ${domain} not registered"
        return 1
    fi
    
    local site_path="$(get_site_path "${domain}")"
    
    if [[ ! -d "${site_path}" ]]; then
        log_error "Site directory not found: ${site_path}"
        return 1
    fi
    
    log_info "Creating backup for ${domain}..."
    
    mkdir -p "${BACKUP_DIR}"
    
    local backup_name="${domain}_${TIMESTAMP}"
    local backup_dir="${BACKUP_DIR}/${backup_name}"
    local backup_archive="${BACKUP_DIR}/${backup_name}.tar.gz"
    
    mkdir -p "${backup_dir}"
    
    cp -r "${site_path}" "${backup_dir}/website/" || log_warning "Failed to copy website files"
    
    local db_name="$(grep "^${domain}:" "${REGISTRY_FILE}" | cut -d: -f2 | sed 's|^.*/||;s|_|.|g')"
    if [[ -z "${db_name}" ]]; then
        db_name="$(basename "${site_path}" | sed 's/\./_/g')"
    fi
    
    if mysqldump -u root --single-transaction --quick "${db_name}" > "${backup_dir}/database.sql" 2>/dev/null; then
        log_info "Database backup created"
    else
        log_warning "Failed to backup database"
    fi
    
    cp -r "${OLS_INSTALL_PATH}/conf/vhosts/${domain}" "${backup_dir}/vhost-config/" 2>/dev/null || log_warning "Failed to backup virtual host config"
    
    cd "${BACKUP_DIR}"
    if tar -czf "${backup_archive}" "${backup_name}/" --exclude='lost+found'; then
        log_success "Backup created: ${backup_archive}"
        rm -rf "${backup_dir}"
        ls -lh "${backup_archive}"
    else
        log_error "Failed to create backup archive"
        return 1
    fi
    
    return 0
}

restore_site() {
    echo -e "\n${BOLD}Restore Site from Backup${NC}\n"
    
    if [[ ! -d "${BACKUP_DIR}" ]] || [[ -z "$(ls -A ${BACKUP_DIR})" ]]; then
        log_error "No backups found"
        return 1
    fi
    
    echo "Available backups:"
    ls -1 "${BACKUP_DIR}"/*.tar.gz 2>/dev/null | nl
    
    read -p "Select backup number: " backup_num
    
    local backup_archive="$(ls -1 "${BACKUP_DIR}"/*.tar.gz 2>/dev/null | sed -n "${backup_num}p")"
    
    if [[ ! -f "${backup_archive}" ]]; then
        log_error "Invalid backup selection"
        return 1
    fi
    
    if ! confirm "Restore from ${backup_archive}? This will overwrite existing files"; then
        log_info "Restore cancelled"
        return 0
    fi
    
    log_info "Extracting backup..."
    
    local temp_extract="${TEMP_DIR}/restore_$$"
    mkdir -p "${temp_extract}"
    
    if ! tar -xzf "${backup_archive}" -C "${temp_extract}"; then
        log_error "Failed to extract backup"
        return 1
    fi
    
    local backup_name="$(basename "${backup_archive}" .tar.gz)"
    local restore_dir="${temp_extract}/${backup_name}"
    
    if [[ -d "${restore_dir}/website" ]]; then
        local site_path="$(ls -d ${restore_dir}/website/* 2>/dev/null | head -1)"
        local domain="$(basename "${site_path}")"
        
        if [[ -d "${SITES_ROOT}/${domain}" ]]; then
            log_warning "Site directory exists, backing up current version"
            mv "${SITES_ROOT}/${domain}" "${SITES_ROOT}/${domain}.backup.${TIMESTAMP}"
        fi
        
        cp -r "${site_path}" "${SITES_ROOT}/${domain}"
        set_site_permissions "${SITES_ROOT}/${domain}"
        
        if [[ -f "${restore_dir}/database.sql" ]]; then
            log_info "Restoring database..."
            local db_name="$(grep "DB_NAME" "${SITES_ROOT}/${domain}/wp-config.php" | grep -oP "'\K[^']+(?=')" | head -1)"
            mysql "${db_name}" < "${restore_dir}/database.sql" || log_warning "Failed to restore database"
        fi
        
        log_success "Site restored successfully"
    else
        log_error "Invalid backup structure"
        return 1
    fi
    
    return 0
}

full_server_snapshot() {
    echo -e "\n${BOLD}Create Full Server Snapshot${NC}\n"
    
    if ! confirm "Create full server snapshot? This may take time"; then
        log_info "Snapshot cancelled"
        return 0
    fi
    
    log_info "Creating full server snapshot..."
    
    mkdir -p "${BACKUP_DIR}"
    
    local snapshot_name="server-snapshot_${TIMESTAMP}"
    local snapshot_dir="${BACKUP_DIR}/${snapshot_name}"
    local snapshot_archive="${BACKUP_DIR}/${snapshot_name}.tar.gz"
    
    mkdir -p "${snapshot_dir}"
    
    log_info "Backing up sites..."
    cp -r "${SITES_ROOT}" "${snapshot_dir}/" || log_warning "Failed to backup sites"
    
    log_info "Backing up OpenLiteSpeed configuration..."
    cp -r "${OLS_INSTALL_PATH}/conf" "${snapshot_dir}/ols-conf/" || log_warning "Failed to backup OLS config"
    
    log_info "Dumping all databases..."
    mysqldump --all-databases --single-transaction --quick > "${snapshot_dir}/all-databases.sql" 2>/dev/null || log_warning "Failed to dump databases"
    
    log_info "Backing up system configuration..."
    cp /etc/mysql/mariadb.conf.d/99-ols-optimizations.cnf "${snapshot_dir}/" 2>/dev/null || true
    cp "${REGISTRY_FILE}" "${snapshot_dir}/" 2>/dev/null || true
    
    cd "${BACKUP_DIR}"
    if tar -czf "${snapshot_archive}" "${snapshot_name}/" --exclude='lost+found' --exclude='*.tmp'; then
        log_success "Server snapshot created: ${snapshot_archive}"
        rm -rf "${snapshot_dir}"
        ls -lh "${snapshot_archive}"
    else
        log_error "Failed to create snapshot archive"
        return 1
    fi
    
    return 0
}

################################################################################
# MAINTENANCE FUNCTIONS
################################################################################

bulk_update_wordpress() {
    echo -e "\n${BOLD}Bulk Update WordPress${NC}\n"
    
    if [[ ! -f "${REGISTRY_FILE}" ]] || [[ ! -s "${REGISTRY_FILE}" ]]; then
        log_info "No sites registered"
        return 0
    fi
    
    log_info "Updating all WordPress installations..."
    
    local updated_count=0
    local failed_count=0
    
    while IFS=: read -r domain site_path timestamp; do
        if [[ ! -d "${site_path}" ]]; then
            log_warning "Site path not found: ${site_path}"
            ((failed_count++))
            continue
        fi
        
        log_info "Updating ${domain}..."
        
        if cd "${site_path}" && wp core update --allow-root 2>/dev/null; then
            log_success "${domain} updated"
            ((updated_count++))
        else
            log_warning "Failed to update ${domain}"
            ((failed_count++))
        fi
    done < "${REGISTRY_FILE}"
    
    log_info "Update complete: ${updated_count} successful, ${failed_count} failed"
    return 0
}

enable_ssl_all_sites() {
    echo -e "\n${BOLD}Enable SSL for All Sites${NC}\n"
    
    if [[ ! -f "${REGISTRY_FILE}" ]] || [[ ! -s "${REGISTRY_FILE}" ]]; then
        log_info "No sites registered"
        return 0
    fi
    
    if ! command_exists certbot; then
        log_error "Certbot not installed"
        return 1
    fi
    
    read -p "Enter email for SSL certificates: " email
    
    if ! validate_email "${email}"; then
        log_error "Invalid email format"
        return 1
    fi
    
    log_info "Obtaining SSL certificates..."
    
    local domains=()
    while IFS=: read -r domain site_path timestamp; do
        if [[ ! -d "${site_path}" ]]; then
            continue
        fi
        domains+=("${domain}")
    done < "${REGISTRY_FILE}"
    
    if [[ ${#domains[@]} -eq 0 ]]; then
        log_error "No valid sites found"
        return 1
    fi
    
    local domains_arg=()
    for domain in "${domains[@]}"; do
        domains_arg+=("-d" "${domain}")
    done
    
    if certbot certonly --standalone -n --agree-tos --email="${email}" "${domains_arg[@]}" 2>/dev/null; then
        log_success "SSL certificates obtained"
        
        ENABLE_SSL=1
        
        for domain in "${domains[@]}"; do
            local site_path="$(get_site_path "${domain}")"
            if [[ -f "${site_path}/wp-config.php" ]]; then
                sed -i "s|http://|https://|g" "${site_path}/wp-config.php"
            fi
        done
        
        systemctl restart lsws || log_warning "Failed to restart OpenLiteSpeed"
        log_success "SSL enabled for all sites"
    else
        log_error "Failed to obtain SSL certificates"
        return 1
    fi
    
    return 0
}

switch_php_version() {
    echo -e "\n${BOLD}Switch PHP Version${NC}\n"
    
    local php_versions=("80" "81" "82" "83" "84")
    
    echo "Available PHP versions:"
    for i in "${!php_versions[@]}"; do
        echo "$((i+1)). PHP ${php_versions[$i]:0:1}.${php_versions[$i]:1:1}"
    done
    
    read -p "Select PHP version number: " php_choice
    
    if [[ -z "${php_choice}" ]] || [[ "${php_choice}" -lt 1 ]] || [[ "${php_choice}" -gt ${#php_versions[@]} ]]; then
        log_error "Invalid selection"
        return 1
    fi
    
    PHP_VERSION="${php_versions[$((php_choice-1))]}"
    
    log_info "Switching to PHP ${PHP_VERSION:0:1}.${PHP_VERSION:1:1}..."
    
    apt-cache show "lsphp${PHP_VERSION}" &>/dev/null || {
        log_error "PHP ${PHP_VERSION:0:1}.${PHP_VERSION:1:1} not available"
        return 1
    }
    
    DEBIAN_FRONTEND=noninteractive apt-get install -y "lsphp${PHP_VERSION}" || {
        log_error "Failed to install PHP ${PHP_VERSION}"
        return 1
    }
    
    systemctl restart lsws || log_warning "Failed to restart OpenLiteSpeed"
    
    log_success "PHP switched to ${PHP_VERSION:0:1}.${PHP_VERSION:1:1}"
    return 0
}

system_audit() {
    echo -e "\n${BOLD}System Audit Report${NC}\n"
    
    echo "=== Server Information ==="
    echo "Hostname: $(hostname)"
    echo "Kernel: $(uname -r)"
    echo "Ubuntu Version: $(lsb_release -ds)"
    echo "Uptime: $(uptime -p)"
    echo ""
    
    echo "=== OpenLiteSpeed ==="
    if systemctl is-active --quiet lsws; then
        echo "Status: Running"
        echo "Version: $(lshttpd -v 2>&1 | grep -oP 'OpenLiteSpeed/\K[0-9.]+')"
    else
        echo "Status: Stopped"
    fi
    echo ""
    
    echo "=== PHP ==="
    if command_exists php; then
        echo "PHP Version: $(php -r 'echo phpversion();')"
    fi
    if [[ -n "${LSPHP_VERSION}" ]]; then
        echo "LiteSpeed PHP: ${LSPHP_VERSION}"
    fi
    echo ""
    
    echo "=== MariaDB ==="
    if systemctl is-active --quiet mariadb; then
        echo "Status: Running"
        echo "Version: $(mysql -V | grep -oP 'Ver\s+\K[0-9.]+')"
        echo "Size: $(mysql -e "SELECT SUM(data_length + index_length) FROM information_schema.TABLES;" -N -N 2>/dev/null | numfmt --to=iec 2>/dev/null || echo 'Unknown')"
    else
        echo "Status: Stopped"
    fi
    echo ""
    
    echo "=== Disk Usage ==="
    df -h / | awk 'NR==2 {printf "Root: %s / %s (%s)\n", $3, $2, $5}'
    df -h "${SITES_ROOT}" | awk 'NR==2 {printf "Sites: %s / %s (%s)\n", $3, $2, $5}'
    echo ""
    
    echo "=== Memory ==="
    free -h | awk '/^Mem:/ {printf "Total: %s, Used: %s, Free: %s\n", $2, $3, $4}'
    echo ""
    
    echo "=== Registered Sites ==="
    if [[ -f "${REGISTRY_FILE}" ]] && [[ -s "${REGISTRY_FILE}" ]]; then
        wc -l < "${REGISTRY_FILE}" | xargs echo "Count:"
    else
        echo "Count: 0"
    fi
    echo ""
    
    echo "=== SSL Certificates ==="
    if certbot certificates 2>/dev/null | grep -q "Certificate Name"; then
        certbot certificates 2>/dev/null | grep "Certificate Name"
    else
        echo "No certificates found"
    fi
    echo ""
    
    echo "=== Firewall ==="
    echo "Status: $(systemctl is-active ufw || echo 'Inactive')"
    echo ""
    
    echo "=== Failed Services ==="
    systemctl list-units --state=failed --no-pager || echo "None"
    echo ""
    
    log_success "Audit complete"
}

enable_auto_maintenance() {
    echo -e "\n${BOLD}Enable Auto Maintenance Cron${NC}\n"
    
    local cron_file="/etc/cron.d/ols-maintenance"
    
    cat > "${cron_file}" <<'EOFCRON'
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

0 2 * * * root /usr/local/bin/ols-wp-update.sh >> /var/log/ols-maintenance.log 2>&1
0 3 * * * root certbot renew --quiet --agree-tos >> /var/log/ols-maintenance.log 2>&1
0 4 * * 0 root /usr/local/bin/ols-backup.sh >> /var/log/ols-maintenance.log 2>&1
0 5 * * * root /usr/local/bin/ols-cleanup.sh >> /var/log/ols-maintenance.log 2>&1
30 1 * * * root logrotate -f /etc/logrotate.d/ols >> /var/log/ols-maintenance.log 2>&1
EOFCRON
    
    chmod 644 "${cron_file}"
    
    cat > /usr/local/bin/ols-wp-update.sh <<'EOFUPDATE'
#!/bin/bash
set -euo pipefail

LOG="/var/log/ols-wp-updates.log"
REGISTRY="/etc/ols-manager/sites-registry.conf"

{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting WordPress updates..."
    
    if [[ ! -f "${REGISTRY}" ]]; then
        echo "Registry file not found"
        exit 0
    fi
    
    while IFS=: read -r domain site_path timestamp; do
        if [[ ! -d "${site_path}" ]]; then
            continue
        fi
        
        if command -v wp &>/dev/null; then
            if cd "${site_path}" && wp core update --allow-root 2>/dev/null; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Updated ${domain}"
            fi
        fi
    done < "${REGISTRY}"
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WordPress updates completed"
} >> "${LOG}" 2>&1
EOFUPDATE
    
    chmod 755 /usr/local/bin/ols-wp-update.sh
    
    cat > /usr/local/bin/ols-backup.sh <<'EOFBACKUP'
#!/bin/bash
set -euo pipefail

LOG="/var/log/ols-backups.log"
REGISTRY="/etc/ols-manager/sites-registry.conf"
BACKUP_DIR="/opt/ols-backups"
RETENTION_DAYS=30

{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting backup cycle..."
    
    mkdir -p "${BACKUP_DIR}"
    
    if [[ -f "${REGISTRY}" ]]; then
        while IFS=: read -r domain site_path timestamp; do
            if [[ ! -d "${site_path}" ]]; then
                continue
            fi
            
            local backup_name="${domain}_$(date +%Y%m%d_%H%M%S)"
            local backup_archive="${BACKUP_DIR}/${backup_name}.tar.gz"
            
            if tar -czf "${backup_archive}" -C "${site_path}" . 2>/dev/null; then
                echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backed up ${domain}"
            fi
        done < "${REGISTRY}"
    fi
    
    find "${BACKUP_DIR}" -name "*.tar.gz" -mtime "+${RETENTION_DAYS}" -delete
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Removed backups older than ${RETENTION_DAYS} days"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Backup cycle completed"
} >> "${LOG}" 2>&1
EOFBACKUP
    
    chmod 755 /usr/local/bin/ols-backup.sh
    
    cat > /usr/local/bin/ols-cleanup.sh <<'EOFCLEANUP'
#!/bin/bash
set -euo pipefail

LOG="/var/log/ols-cleanup.log"
REGISTRY="/etc/ols-manager/sites-registry.conf"

{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting cleanup..."
    
    if [[ -f "${REGISTRY}" ]]; then
        while IFS=: read -r domain site_path timestamp; do
            if [[ ! -d "${site_path}" ]]; then
                continue
            fi
            
            find "${site_path}/wp-content/cache" -type f -mtime +7 -delete 2>/dev/null || true
            find "${site_path}/wp-content/uploads/cache" -type f -mtime +7 -delete 2>/dev/null || true
        done < "${REGISTRY}"
    fi
    
    find /tmp -name "*.tmp" -mtime +1 -delete 2>/dev/null || true
    
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Cleanup completed"
} >> "${LOG}" 2>&1
EOFCLEANUP
    
    chmod 755 /usr/local/bin/ols-cleanup.sh
    
    systemctl restart cron || log_warning "Failed to restart cron"
    
    log_success "Auto maintenance enabled"
    echo "Maintenance tasks:"
    echo "- WordPress updates: Daily at 2:00 AM"
    echo "- SSL renewal: Daily at 3:00 AM"
    echo "- Site backups: Weekly Sunday at 4:00 AM"
    echo "- Cache cleanup: Daily at 5:00 AM"
    echo "- Log rotation: Daily at 1:30 AM"
}

restart_services() {
    echo -e "\n${BOLD}Restart Services${NC}\n"
    
    log_info "Restarting OpenLiteSpeed..."
    systemctl restart lsws || log_error "Failed to restart OpenLiteSpeed"
    
    log_info "Restarting MariaDB..."
    systemctl restart mariadb || log_error "Failed to restart MariaDB"
    
    log_info "Restarting Fail2Ban..."
    systemctl restart fail2ban || log_error "Failed to restart Fail2Ban"
    
    sleep 2
    
    echo ""
    echo "Service Status:"
    systemctl status lsws --no-pager | grep "Active:" || echo "OpenLiteSpeed: Error checking status"
    systemctl status mariadb --no-pager | grep "Active:" || echo "MariaDB: Error checking status"
    systemctl status fail2ban --no-pager | grep "Active:" || echo "Fail2Ban: Error checking status"
    
    log_success "Services restarted"
}

view_logs() {
    echo -e "\n${BOLD}View Logs${NC}\n"
    
    echo "1. OLS Manager Log"
    echo "2. OpenLiteSpeed Access Log"
    echo "3. OpenLiteSpeed Error Log"
    echo "4. MariaDB Error Log"
    echo "5. Fail2Ban Log"
    echo "6. System Messages"
    echo "0. Back to menu"
    
    read -p "Select log: " log_choice
    
    case "${log_choice}" in
        1)
            tail -f "${LOG_FILE}"
            ;;
        2)
            tail -f "${OLS_INSTALL_PATH}/logs/access.log"
            ;;
        3)
            tail -f "${OLS_INSTALL_PATH}/logs/error.log"
            ;;
        4)
            tail -f /var/log/mysql/error.log
            ;;
        5)
            tail -f /var/log/fail2ban.log
            ;;
        6)
            tail -f /var/log/syslog
            ;;
        0)
            return 0
            ;;
        *)
            log_error "Invalid selection"
            ;;
    esac
}

################################################################################
# MENU LOOP
################################################################################

main_menu() {
    clear
    echo -e "${BOLD}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║   ${BLUE}OpenLiteSpeed + WordPress Server Manager${NC} ${BOLD}v${SCRIPT_VERSION}${NC}${BOLD}     ║${NC}"
    echo -e "${BOLD}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "1.  Install complete stack"
    echo "2.  Create new site"
    echo "3.  Register existing site"
    echo "4.  List registered sites"
    echo "5.  Backup single site"
    echo "6.  Restore site from backup"
    echo "7.  Bulk update all WordPress"
    echo "8.  Enable SSL for all sites"
    echo "9.  Switch PHP version"
    echo "10. System audit"
    echo "11. Full server snapshot"
    echo "12. Enable auto maintenance cron"
    echo "13. Restart all services"
    echo "14. View logs"
    echo "0.  Exit"
    echo ""
}

handle_menu_input() {
    local choice="$1"
    
    case "${choice}" in
        1)
            install_full_stack
            menu_pause
            ;;
        2)
            create_new_site
            menu_pause
            ;;
        3)
            register_existing_site
            menu_pause
            ;;
        4)
            list_sites
            menu_pause
            ;;
        5)
            echo -e "\n${BOLD}Backup Single Site${NC}"
            read -p "Enter domain name: " domain
            if validate_domain "${domain}"; then
                backup_site "${domain}"
            else
                log_error "Invalid domain format"
            fi
            menu_pause
            ;;
        6)
            restore_site
            menu_pause
            ;;
        7)
            bulk_update_wordpress
            menu_pause
            ;;
        8)
            enable_ssl_all_sites
            menu_pause
            ;;
        9)
            switch_php_version
            menu_pause
            ;;
        10)
            system_audit
            menu_pause
            ;;
        11)
            full_server_snapshot
            menu_pause
            ;;
        12)
            enable_auto_maintenance
            menu_pause
            ;;
        13)
            restart_services
            menu_pause
            ;;
        14)
            view_logs
            ;;
        0)
            log_info "Exiting..."
            exit 0
            ;;
        *)
            log_error "Invalid menu selection"
            menu_pause
            ;;
    esac
}

main() {
    check_root
    check_ubuntu_version
    initialize_logging
    
    while true; do
        main_menu
        read -p "Select option: " menu_choice
        handle_menu_input "${menu_choice}"
        clear
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi