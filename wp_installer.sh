#!/usr/bin/env bash
set -e

BASE="/opt/ols-manager"
SITES="$BASE/sites.db"
BACKUP="$BASE/backups"
OLS="/usr/local/lsws"
WWW="/var/www"

mkdir -p $BASE $BACKUP
touch $SITES

#####################################
header(){
clear
echo "======================================"
echo " OLS ENTERPRISE SERVER MANAGER"
echo "======================================"
}

pause(){ read -p "Enter..."; }

run(){
 echo "[EXEC] $*"
 eval "$*"
}

#####################################
register_site(){
read -p "Domain: " domain
read -p "Path (example /var/www/site): " path
echo "$domain|$path" >> $SITES
echo "Registered."
pause
}

#####################################
list_sites(){
echo "=== Registered Sites ==="
nl -w2 -s') ' $SITES || true
pause
}

#####################################
install_site(){

read -p "Domain: " domain
read -p "DB Name: " db
read -p "DB User: " dbu
read -s -p "DB Pass: " dbp; echo

path="$WWW/$domain"

run "mkdir -p $path"
run "cd $WWW && wget https://wordpress.org/latest.tar.gz"
run "tar xf $WWW/latest.tar.gz"
run "mv $WWW/wordpress/* $path"
run "rm -rf $WWW/wordpress $WWW/latest.tar.gz"

run "mysql -e \"CREATE DATABASE $db\""
run "mysql -e \"CREATE USER '$dbu'@'localhost' IDENTIFIED BY '$dbp'\""
run "mysql -e \"GRANT ALL ON $db.* TO '$dbu'@'localhost'\""

run "cp $path/wp-config-sample.php $path/wp-config.php"
run "sed -i 's/database_name_here/$db/' $path/wp-config.php"
run "sed -i 's/username_here/$dbu/' $path/wp-config.php"
run "sed -i 's/password_here/$dbp/' $path/wp-config.php"

echo "$domain|$path" >> $SITES
echo "Site installed + registered."
pause
}

#####################################
backup_site(){

nl $SITES
read -p "Select site number: " n
line=$(sed -n "${n}p" $SITES)

domain=$(echo $line|cut -d\| -f1)
path=$(echo $line|cut -d\| -f2)

run "mkdir -p $BACKUP/$domain"
run "tar czf $BACKUP/$domain/files.tar.gz $path"
run "mysqldump --all-databases > $BACKUP/$domain/db.sql"

echo "Backup saved → $BACKUP/$domain"
pause
}

#####################################
restore_site(){

read -p "Backup folder path: " src
read -p "Restore path: " dest

run "tar xzf $src/files.tar.gz -C /"
run "mysql < $src/db.sql"

echo "Restore done."
pause
}

#####################################
bulk_update_wp(){
while read line; do
path=$(echo $line|cut -d\| -f2)
run "cd $path && wp core update --allow-root || true"
done < $SITES
pause
}

#####################################
ssl_all(){

while read line; do
domain=$(echo $line|cut -d\| -f1)
run "certbot certonly --standalone -d $domain --non-interactive --agree-tos -m admin@$domain || true"
done < $SITES

pause
}

#####################################
system_audit(){

echo "===== SYSTEM AUDIT ====="
echo "CPU:"; lscpu | grep "Model name"
echo
echo "RAM:"; free -h
echo
echo "Disk:"; df -h
echo
echo "Top Load:"; uptime
echo
echo "OLS Status:"; systemctl status lsws --no-pager
echo
echo "MariaDB:"; systemctl status mariadb --no-pager

pause
}

#####################################
php_switch(){

apt search lsphp | grep lsphp
read -p "Install version: " v

run "apt install -y $v"
run "ln -sf $OLS/$v/bin/php /usr/bin/php"
run "$OLS/bin/lswsctrl restart"

pause
}

#####################################
snapshot(){

snap="$BACKUP/full_snapshot_$(date +%s)"
mkdir -p $snap

run "tar czf $snap/ols.tar.gz $OLS"
run "tar czf $snap/www.tar.gz $WWW"
run "mysqldump --all-databases > $snap/db.sql"

echo "Snapshot ready → $snap"
pause
}

#####################################
cron_maintenance(){

echo "Setting auto maintenance..."

(crontab -l 2>/dev/null; echo "0 3 * * * $0 --auto-update") | crontab -

echo "Daily maintenance enabled."
pause
}

#####################################
auto_update(){

while read line; do
path=$(echo $line|cut -d\| -f2)
cd $path
wp core update --allow-root || true
wp plugin update --all --allow-root || true
wp theme update --all --allow-root || true
done < $SITES

}

#####################################
if [[ "${1:-}" == "--auto-update" ]]; then
auto_update
exit
fi

#####################################
MENU
#####################################
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

read -p "Select: " c

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
0) exit ;;
esac
done
