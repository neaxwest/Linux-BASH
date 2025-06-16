#!/usr/bin/env bash

clear
cat <<"EOF"
    ____  __             __  ___         ___          _____                          
   / __ \/ /__  _  __   /  |/  /__  ____/ (_)___ _   / ___/___  ______   _____  _____
  / /_/ / / _ \| |/_/  / /|_/ / _ \/ __  / / __ `/   \__ \/ _ \/ ___/ | / / _ \/ ___/
 / ____/ /  __/>  <   / /  / /  __/ /_/ / / /_/ /   ___/ /  __/ /   | |/ /  __/ /    
/_/   /_/\___/_/|_|  /_/  /_/\___/\__,_/_/\__,_/   /____/\___/_/    |___/\___/_/     
EOF

echo -e "\nStarting Plex installation..."

APP="Plex"
IP=$(hostname -I | awk '{print $1}')

echo -e "\nUpdating system..."
apt-get update && apt-get upgrade -y

echo -e "\nInstalling dependencies..."
apt-get install -y curl wget apt-transport-https gnupg2 lsb-release

echo -e "\nAdding Plex APT repository..."
curl https://downloads.plex.tv/plex-keys/PlexSign.key | gpg --dearmor -o /usr/share/keyrings/plex.gpg
echo "deb [signed-by=/usr/share/keyrings/plex.gpg] https://downloads.plex.tv/repo/deb public main" > /etc/apt/sources.list.d/plexmediaserver.list

echo -e "\nInstalling Plex..."
apt-get update
apt-get install -y plexmediaserver

echo -e "\nEnabling and starting Plex service..."
systemctl enable plexmediaserver
systemctl start plexmediaserver

echo -e "\n? Plex installed successfully!"
echo -e "Access it at: http://${IP}:32400/web\n"
