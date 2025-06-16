#!/usr/bin/env bash

# ---------- ��������� ----------
CT_ID=$(pvesh get /cluster/nextid)
HOSTNAME="zabbix"
DISK_SIZE="6G"
CPU_COUNT="2"
RAM_SIZE="4096"
BRIDGE="vmbr0"
TEMPLATE="debian-12-standard_*.tar.zst"
STORAGE="local-lvm"
ZBX_PORT=80

# ---------- �������� ----------
echo "? �������� ������� ������� Debian 12..."
if ! pveam list | grep -q "$TEMPLATE"; then
    echo "?? ���������� ������� Debian 12..."
    pveam update
    pveam download local debian-12-standard_2023-*.tar.zst
fi

echo "?? �������� LXC ���������� ($CT_ID)..."
pct create $CT_ID $(pveam list local | grep debian-12 | awk '{print $1}') \
    -hostname $HOSTNAME \
    -cores $CPU_COUNT \
    -memory $RAM_SIZE \
    -rootfs $STORAGE:$DISK_SIZE \
    -net0 name=eth0,bridge=$BRIDGE,ip=dhcp \
    -features nesting=1 \
    -unprivileged 1 \
    -ostype debian \
    -startup order=2

echo "?? ������ ����������..."
pct start $CT_ID
sleep 5

echo "?? ��������� IP-������ ����������..."
CT_IP=""
for i in {1..10}; do
  CT_IP=$(pct exec $CT_ID -- hostname -I | awk '{print $1}')
  [[ -n "$CT_IP" ]] && break
  sleep 2
done

if [[ -z "$CT_IP" ]]; then
    echo "? �� ������� �������� IP ����������"
    exit 1
fi

echo "?? ��������� Zabbix ������ ����������..."
pct exec $CT_ID -- bash -c "apt update && apt install -y curl gnupg lsb-release"

pct exec $CT_ID -- bash -c "
wget https://repo.zabbix.com/zabbix/7.0/debian/pool/main/z/zabbix-release/zabbix-release_7.0-1%2Bdebian12_all.deb -O /tmp/zabbix-release.deb &&
dpkg -i /tmp/zabbix-release.deb &&
apt update &&
apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-apache-conf zabbix-sql-scripts zabbix-agent mariadb-server"

echo "?? ��������� MariaDB � Zabbix ��..."
pct exec $CT_ID -- bash -c "
mysql -e \"
create database zabbix character set utf8mb4 collate utf8mb4_bin;
create user zabbix@localhost identified by 'zabbixpass';
grant all privileges on zabbix.* to zabbix@localhost;
flush privileges;
\" &&
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql -uzabbix -pzabbixpass zabbix"

echo "??? ������������ zabbix_server.conf"
pct exec $CT_ID -- sed -i 's/# DBPassword=/DBPassword=zabbixpass/' /etc/zabbix/zabbix_server.conf

echo "? ������ Zabbix-��������..."
pct exec $CT_ID -- systemctl restart mariadb
pct exec $CT_ID -- systemctl enable zabbix-server zabbix-agent apache2
pct exec $CT_ID -- systemctl restart zabbix-server zabbix-agent apache2

echo ""
echo "?? ������! Zabbix �������� �� ������:"
echo "?? http://$CT_IP/zabbix"
echo "�����: Admin"
echo "������: zabbix"
