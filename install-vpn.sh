#!/bin/bash
# Script Auto Install VPN (SSH-V2Ray) untuk Ubuntu 20.04
# Domain: bytrix.my.id

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Fungsi untuk menampilkan pesan
function print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

function print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

function print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

function print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Cek apakah script dijalankan sebagai root
if [ "$(id -u)" != "0" ]; then
   print_error "Script ini harus dijalankan sebagai root!"
   exit 1
fi

# Cek apakah sistem operasi Ubuntu 20.04
if [[ $(lsb_release -rs) != "20.04" ]]; then
    print_error "Script ini hanya berfungsi pada Ubuntu 20.04!"
    exit 1
fi

# Variabel
DOMAIN="bytrix.my.id"
EMAIL="admin@${DOMAIN}"
UUID=$(cat /proc/sys/kernel/random/uuid)
VMESS_PATH="/v2ray"
VLESS_PATH="/vless"
TROJAN_PATH="/trojan"

# Mendapatkan IP VPS
IP=$(curl -s ipv4.icanhazip.com)

print_info "Memulai instalasi VPN (SSH-V2Ray) pada Ubuntu 20.04"
print_info "Domain: ${DOMAIN}"
print_info "IP VPS: ${IP}"

# Update dan upgrade sistem
print_info "Memperbarui sistem..."
apt update -y
apt upgrade -y

# Instalasi paket yang diperlukan
print_info "Menginstal paket yang diperlukan..."
apt install -y curl wget socat git unzip lsof net-tools jq build-essential

# Menonaktifkan IPv6
print_info "Menonaktifkan IPv6..."
sysctl -w net.ipv6.conf.all.disable_ipv6=1
sysctl -w net.ipv6.conf.default.disable_ipv6=1
sysctl -w net.ipv6.conf.lo.disable_ipv6=1
echo -e "net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
sysctl -p

# Konfigurasi waktu
print_info "Mengatur zona waktu ke Asia/Jakarta..."
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime

# Konfigurasi firewall
print_info "Mengkonfigurasi firewall..."
apt install -y ufw
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 1194/udp
ufw allow 8080/tcp
ufw allow 8880/tcp
ufw allow 8443/tcp
ufw allow 7300/tcp
ufw allow 7300/udp
ufw --force enable

# Instalasi BBR
print_info "Menginstal BBR untuk optimasi TCP..."
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p

# Instalasi Nginx
print_info "Menginstal dan mengkonfigurasi Nginx..."
apt install -y nginx
systemctl enable nginx
systemctl start nginx

# Konfigurasi Nginx
cat > /etc/nginx/conf.d/${DOMAIN}.conf << END
server {
    listen 80;
    server_name ${DOMAIN} www.${DOMAIN};
    
    location / {
        root /var/www/html;
        index index.html index.htm;
    }
    
    location ${VMESS_PATH} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    
    location ${VLESS_PATH} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10002;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
    
    location ${TROJAN_PATH} {
        proxy_redirect off;
        proxy_pass http://127.0.0.1:10003;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$http_host;
    }
}
END

# Membuat halaman web sederhana
mkdir -p /var/www/html
cat > /var/www/html/index.html << END
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to ${DOMAIN}</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f4;
            color: #333;
            text-align: center;
            padding: 50px;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: white;
            padding: 20px;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to ${DOMAIN}</h1>
        <p>Server is running properly.</p>
        <p>Powered by V2Ray VPN</p>
    </div>
</body>
</html>
END

# Restart Nginx
systemctl restart nginx

# Instalasi Certbot untuk SSL
print_info "Menginstal Certbot dan mendapatkan sertifikat SSL..."
apt install -y certbot python3-certbot-nginx
certbot --nginx --non-interactive --agree-tos --email ${EMAIL} -d ${DOMAIN} -d www.${DOMAIN}

# Instalasi V2Ray
print_info "Menginstal V2Ray..."
bash <(curl -L https://raw.githubusercontent.com/v2fly/fhs-install-v2ray/master/install-release.sh)

# Konfigurasi V2Ray
print_info "Mengkonfigurasi V2Ray..."
mkdir -p /usr/local/etc/v2ray
cat > /usr/local/etc/v2ray/config.json << END
{
  "log": {
    "loglevel": "warning"
  },
  "inbounds": [
    {
      "port": 10001,
      "listen": "127.0.0.1",
      "protocol": "vmess",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "alterId": 0
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "wsSettings": {
          "path": "${VMESS_PATH}"
        }
      }
    },
    {
      "port": 10002,
      "listen": "127.0.0.1",
      "protocol": "vless",
      "settings": {
        "clients": [
          {
            "id": "${UUID}",
            "level": 0,
            "email": "user@${DOMAIN}"
          }
        ],
        "decryption": "none"
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "${VLESS_PATH}"
        }
      }
    },
    {
      "port": 10003,
      "listen": "127.0.0.1",
      "protocol": "trojan",
      "settings": {
        "clients": [
          {
            "password": "${UUID}",
            "level": 0,
            "email": "trojan@${DOMAIN}"
          }
        ]
      },
      "streamSettings": {
        "network": "ws",
        "security": "none",
        "wsSettings": {
          "path": "${TROJAN_PATH}"
        }
      }
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom",
      "settings": {}
    }
  ]
}
END

# Restart dan aktifkan V2Ray
systemctl restart v2ray
systemctl enable v2ray

# Konfigurasi SSH
print_info "Mengkonfigurasi SSH..."
sed -i 's/#Port 22/Port 22/' /etc/ssh/sshd_config
sed -i 's/PasswordAuthentication no/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl restart ssh

# Membuat user untuk SSH
print_info "Membuat user untuk SSH..."
useradd -m -s /bin/bash vpnuser
echo "vpnuser:vpnpassword" | chpasswd

# Membuat file konfigurasi untuk client
mkdir -p /root/v2ray-config
cat > /root/v2ray-config/vmess-config.json << END
{
  "v": "2",
  "ps": "${DOMAIN} - VMess",
  "add": "${DOMAIN}",
  "port": "443",
  "id": "${UUID}",
  "aid": "0",
  "net": "ws",
  "type": "none",
  "host": "${DOMAIN}",
  "path": "${VMESS_PATH}",
  "tls": "tls"
}
END

# Membuat file informasi
cat > /root/vpn-info.txt << END
===========================================================
      INFORMASI VPN SERVER (SSH-V2Ray) - ${DOMAIN}
===========================================================

IP VPS        : ${IP}
Domain        : ${DOMAIN}

-----------------------------------------------------------
INFORMASI SSH:
-----------------------------------------------------------
Host          : ${DOMAIN}
Port          : 22
Username      : vpnuser
Password      : vpnpassword

-----------------------------------------------------------
INFORMASI V2RAY VMESS:
-----------------------------------------------------------
Address       : ${DOMAIN}
Port          : 443
UUID          : ${UUID}
AlterID       : 0
Security      : auto
Network       : ws
Path          : ${VMESS_PATH}
TLS           : tls

VMess URL: vmess://$(echo -n '{"v":"2","ps":"'${DOMAIN}' - VMess","add":"'${DOMAIN}'","port":"443","id":"'${UUID}'","aid":"0","net":"ws","type":"none","host":"'${DOMAIN}'","path":"'${VMESS_PATH}'","tls":"tls"}' | base64 -w 0)

-----------------------------------------------------------
INFORMASI V2RAY VLESS:
-----------------------------------------------------------
Address       : ${DOMAIN}
Port          : 443
UUID          : ${UUID}
Network       : ws
Path          : ${VLESS_PATH}
TLS           : tls

VLESS URL: vless://${UUID}@${DOMAIN}:443?path=${VLESS_PATH}&security=tls&encryption=none&type=ws#${DOMAIN}%20-%20VLESS

-----------------------------------------------------------
INFORMASI TROJAN:
-----------------------------------------------------------
Address       : ${DOMAIN}
Port          : 443
Password      : ${UUID}
Network       : ws
Path          : ${TROJAN_PATH}
TLS           : tls

Trojan URL: trojan://${UUID}@${DOMAIN}:443?path=${TROJAN_PATH}&security=tls&type=ws#${DOMAIN}%20-%20Trojan

===========================================================
      SCRIPT BY CLINE - DIBUAT PADA $(date)
===========================================================
END

print_success "Instalasi VPN (SSH-V2Ray) selesai!"
print_info "Informasi VPN tersimpan di: /root/vpn-info.txt"
print_info "Konfigurasi VMess tersimpan di: /root/v2ray-config/vmess-config.json"
print_info "Untuk melihat informasi VPN, jalankan: cat /root/vpn-info.txt"

# Reboot sistem
print_warning "Sistem akan di-reboot dalam 10 detik..."
sleep 10
reboot
