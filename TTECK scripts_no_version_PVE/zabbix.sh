#!/bin/bash

# ============================
# Установка Zabbix 7.0 в LXC на Debian 12
# Автор: модифицирован для Proxmox 7.x/8.x
# ============================

# Настройки — изменяй под себя
CT_ID=$(pvesh get /cluster/nextid)
HOSTNAME="zabbix"
STORAGE="local"          # имя хранилища с шаблонами, обычно 'local'
DISK_SIZE="6"            # размер диска в ГБ, число без 'G'
RAM="4096"               # память в МБ
CPU="2"                  # количество ядер
BRIDGE="vmbr0"           # сетевой мост
TEMPLATE="debian-12-standard_20230822.tar.zst"

echo "⚙️  Используем настройки:"
echo "  CT_ID: $CT_ID"
echo "  HOSTNAME: $HOSTNAME"
echo "  STORAGE: $STORAGE"
echo "  DISK_SIZE: ${DISK_SIZE}GB"
echo "  RAM: ${RAM}MB"
echo "  CPU cores: $CPU"
echo "  BRIDGE: $BRIDGE"
echo "  TEMPLATE: $TEMPLATE"
echo ""

# Проверка наличия шаблона
echo "🔍 Проверяем наличие шаблона Debian 12..."
if ! pveam list $STORAGE | grep -q "$TEMPLATE"; then
  echo "📦 Шаблон не найден, загружаем..."
  pveam update
  pveam download $STORAGE $TEMPLATE
else
  echo "✔ Шаблон уже загружен."
fi

# Создание LXC контейнера
echo "🚀 Создаём LXC контейнер с ID $CT_ID..."
pct create $CT_ID $STORAGE:vztmpl/$TEMPLATE \
  -hostname $HOSTNAME \
  -cores $CPU \
  -memory $RAM \
  -rootfs $STORAGE:$DISK_SIZE \
  -net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
  -unprivileged 1 \
  -features nesting=1 \
  -ostype debian \
  -start 1

if [ $? -ne 0 ]; then
  echo "❌ Ошибка создания контейнера!"
  exit 1
fi

echo "⏳ Ждём пока контейнер запустится..."
sleep 10

# Установка Zabbix и зависимостей
echo "📥 Устанавливаем Zabbix и MariaDB в контейнер..."
pct exec $CT_ID -- bash -c "
apt update && apt upgrade -y &&
apt install -y wget curl gnupg lsb-release mariadb-server apache2 php php-mysql php-gd php-xml php-bcmath php-mbstring libapache2-mod-php unzip &&
wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-1%2Bdebian12_all.deb -O /tmp/zabbix-release.deb &&
dpkg -i /tmp/zabbix-release.deb &&
apt update &&
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent
"

if [ $? -ne 0 ]; then
  echo "❌ Ошибка при установке Zabbix!"
  exit 1
fi

# Настройка базы данных
echo "🛠 Настраиваем базу данных Zabbix..."
pct exec $CT_ID -- bash -c "
mysql -e \"
CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'zabbixpass';
GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
FLUSH PRIVILEGES;
\" &&
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbixpass zabbix &&
sed -i 's/# DBPassword=/DBPassword=zabbixpass/' /etc/zabbix/zabbix_server.conf
"

if [ $? -ne 0 ]; then
  echo "❌ Ошибка настройки базы данных!"
  exit 1
fi

# Запуск сервисов
echo "▶️ Запускаем и включаем сервисы..."
pct exec $CT_ID -- bash -c "
systemctl enable mariadb zabbix-server zabbix-agent apache2 &&
systemctl restart mariadb zabbix-server zabbix-agent apache2
"

echo ""
IP=$(pct exec $CT_ID -- hostname -I | awk '{print $1}')
echo "✅ Установка завершена!"
echo "🌐 Открой в браузере: http://$IP/zabbix"
echo "🔐 Логин: Admin | Пароль: zabbix"
