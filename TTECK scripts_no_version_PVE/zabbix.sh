#!/usr/bin/env bash

# Автор: модифицированный под PVE 7.x
# Установка Zabbix 7.0 в LXC контейнер на Debian 12

# ==== Настройки ====
CT_ID=$(pvesh get /cluster/nextid)
HOSTNAME="zabbix"
STORAGE="local-lvm"
DISK_SIZE="6G"
RAM="4096"
CPU="2"
BRIDGE="vmbr0"
TEMPLATE="debian-12-standard_20230822.tar.zst"

# ==== Проверка и загрузка шаблона ====
if ! pveam list local | grep -q "$TEMPLATE"; then
  echo "📦 Загружаем шаблон Debian 12..."
  pveam update
  pveam download local $TEMPLATE
fi

# ==== Создание LXC ====
echo "🚀 Создание LXC контейнера ID $CT_ID..."
pct create $CT_ID local:vztmpl/$TEMPLATE \
  -hostname $HOSTNAME \
  -cores $CPU \
  -memory $RAM \
  -rootfs $STORAGE:$DISK_SIZE \
  -net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  -unprivileged 1 \
  -features nesting=1 \
  -ostype debian \
  -start 1

echo "⏳ Ожидание старта контейнера..."
sleep 5

# ==== Установка Zabbix ====
echo "📥 Установка Zabbix и MariaDB в контейнер..."
pct exec $CT_ID -- bash -c "
apt update &&
apt install -y wget curl gnupg lsb-release mariadb-server apache2 php php-mysql php-gd php-xml php-bcmath php-mbstring libapache2-mod-php unzip &&
wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-1%2Bdebian12_all.deb -O /tmp/zabbix-release.deb &&
dpkg -i /tmp/zabbix-release.deb &&
apt update &&
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent
"

# ==== Настройка БД ====
echo "🛠️ Настройка базы данных Zabbix..."
pct exec $CT_ID -- bash -c "
mysql -e \"
create database zabbix character set utf8mb4 collate utf8mb4_bin;
create user zabbix@localhost identified by 'zabbixpass';
grant all privileges on zabbix.* to zabbix@localhost;
flush privileges;
\" &&
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbixpass zabbix &&
sed -i 's/# DBPassword=/DBPassword=zabbixpass/' /etc/zabbix/zabbix_server.conf
"

# ==== Запуск сервисов ====
pct exec $CT_ID -- bash -c "
systemctl enable mariadb zabbix-server zabbix-agent apache2 &&
systemctl restart mariadb zabbix-server zabbix-agent apache2
"

# ==== Вывод IP ====
IP=$(pct exec $CT_ID -- hostname -I | awk '{print $1}')
echo ""
echo "✅ Установка завершена!"
echo "🌐 Открой в браузере: http://$IP/zabbix"
echo "🔐 Логин: Admin | Пароль: zabbix"
