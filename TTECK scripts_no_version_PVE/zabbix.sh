#!/usr/bin/env bash

# ----------- НАСТРОЙКИ --------------
CT_ID=$(pvesh get /cluster/nextid)
HOSTNAME="zabbix"
STORAGE="local-lvm"
DISK_SIZE="6G"
MEMORY="4096"
CPUS="2"
BRIDGE="vmbr0"
OS_TEMPLATE="debian-12-standard_20230822.tar.zst"

# ----------- ПОДГОТОВКА -------------
echo "⏳ Проверка шаблона Debian 12..."
if ! pveam available | grep -q "$OS_TEMPLATE"; then
  echo "📦 Скачиваем шаблон $OS_TEMPLATE"
  pveam update
  pveam download local $OS_TEMPLATE
fi

echo "🧱 Создание LXC контейнера..."
pct create $CT_ID local:vztmpl/$OS_TEMPLATE \
  -hostname $HOSTNAME \
  -cores $CPUS \
  -memory $MEMORY \
  -rootfs $STORAGE:$DISK_SIZE \
  -net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  -unprivileged 1 \
  -features nesting=1 \
  -ostype debian \
  -start 1

echo "▶️ Контейнер создан с ID $CT_ID. Ждём запуска..."
sleep 5

# ----------- УСТАНОВКА ZABBIX ------------
echo "📥 Установка Zabbix в контейнер..."
pct exec $CT_ID -- bash -c "
apt update
apt install -y wget curl gnupg lsb-release mariadb-server apache2 php php-mysql php-gd php-xml php-bcmath php-mbstring libapache2-mod-php unzip

wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-1%2Bdebian12_all.deb -O /tmp/zabbix-release.deb
dpkg -i /tmp/zabbix-release.deb
apt update
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent

mysql -e \"
create database zabbix character set utf8mb4 collate utf8mb4_bin;
create user zabbix@localhost identified by 'zabbixpass';
grant all privileges on zabbix.* to zabbix@localhost;
flush privileges;
\"

zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbixpass zabbix

sed -i 's/# DBPassword=/DBPassword=zabbixpass/' /etc/zabbix/zabbix_server.conf

systemctl enable zabbix-server zabbix-agent apache2
systemctl restart mariadb zabbix-server zabbix-agent apache2
"

# ---------- ВЫВОД ---------------
echo "✅ Установка завершена!"
IP=$(pct exec $CT_ID -- hostname -I | awk '{print $1}')
echo "🌐 Открой в браузере: http://$IP/zabbix"
echo "🔐 Логин: Admin | Пароль: zabbix"
