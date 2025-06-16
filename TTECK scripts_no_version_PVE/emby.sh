#!/usr/bin/env bash

clear
cat <<"EOF"
    ______          __         
   / ____/___ ___  / /_  __  __
  / __/ / __  __ \/ __ \/ / / /
 / /___/ / / / / / /_/ / /_/ / 
/_____/_/ /_/ /_/_.___/\__, /  
                      /____/   
EOF

echo -e "Starting Emby installation..."

APP="Emby"
IP=$(hostname -I | awk '{print $1}')

# Пример установки для Ubuntu 22.04 LXC
echo -e "\nUpdating system..."
apt-get update && apt-get upgrade -y

echo -e "\nInstalling dependencies..."
apt-get install -y wget curl apt-transport-https software-properties-common gnupg2

echo -e "\nDownloading latest Emby release..."
LATEST=$(curl -sL https://api.github.com/repos/MediaBrowser/Emby.Releases/releases/latest | grep '"tag_name":' | cut -d'"' -f4)
wget https://github.com/MediaBrowser/Emby.Releases/releases/download/${LATEST}/emby-server-deb_${LATEST}_amd64.deb

echo -e "\nInstalling Emby..."
dpkg -i emby-server-deb_${LATEST}_amd64.deb
apt-get install -f -y  # На случай зависимостей
rm emby-server-deb_${LATEST}_amd64.deb

echo -e "\nEnabling and starting Emby service..."
systemctl enable emby-server
systemctl start emby-server

echo -e "\n? Emby installed successfully!"
echo -e "Access it at: http://${IP}:8096\n"
