#!/usr/bin/env bash
# Скрипт установки Dashy, адаптированный с убранной проверкой версии Proxmox
# Источник: https://github.com/tteck/Proxmox

source <(curl -s https://raw.githubusercontent.com/tteck/Proxmox/main/misc/build.func)

# Проверка версии Proxmox (закомментирована, чтобы избежать ошибки)
# if [[ $(pveversion -v | grep "pve-manager" | awk '{print $2}') < "8.1" ]]; then
#   echo "? This version of Proxmox Virtual Environment is not supported"
#   echo "Requires Proxmox Virtual Environment Version 8.1 or later."
#   exit 1
# fi

function header_info {
  clear
  cat <<"EOF"
 ____ __
/ __ ____ / / __ __
/ / / / __ / / __ / / / /
/ // / /_/ ( ) / / / /_/ /
//_,/// //_, /
/_/
EOF
}

header_info
echo -e "Loading..."

APP="Dashy"
var_disk="6"
var_cpu="2"
var_ram="2048"
var_os="debian"
var_version="12"

variables
color
catch_errors

function default_settings() {
  CT_TYPE="1"
  PW=""
  CT_ID=NEXTID
  HN=NEXTID
  NSAPP=""
  DISK_SIZE="$var_disk"
  CORE_COUNT="$var_cpu"
  RAM_SIZE="$var_ram"
  BRG="vmbr0"
  NET="dhcp"
  GATE=""
  APT_CACHER=""
  APT_CACHER_IP=""
  DISABLEIP6="no"
  MTU=""
  SD=""
  NS=""
  MAC=""
  VLAN=""
  SSH="no"
  VERB="no"
  echo_default
}

function update_script() {
  header_info
  if [[ ! -d /opt/dashy/public/ ]]; then
    msg_error "No ${APP} Installation Found!"
    exit
  fi

  RELEASE=$(curl -sL https://api.github.com/repos/Lissy93/dashy/releases/latest | grep '"tag_name":' | cut -d '"' -f 4)
  CURRENT_VERSION=""
  if [[ -f /opt/${APP}_version.txt ]]; then
    CURRENT_VERSION=$(cat /opt/${APP}_version.txt)
  fi

  if [[ "${RELEASE}" != "${CURRENT_VERSION}" ]] || [[ ! -f /opt/${APP}_version.txt ]]; then
    msg_info "Stopping ${APP}"
    systemctl stop dashy
    msg_ok "Stopped ${APP}"

    msg_info "Backing up conf.yml"
    cd ~
    if [[ -f /opt/dashy/public/conf.yml ]]; then
      cp -R /opt/dashy/public/conf.yml conf.yml
    else
      cp -R /opt/dashy/user-data/conf.yml conf.yml
    fi
    msg_ok "Backed up conf.yml"

    msg_info "Updating ${APP} to ${RELEASE}"
    rm -rf /opt/dashy
    mkdir -p /opt/dashy
    wget -qO- https://github.com/Lissy93/dashy/archive/refs/tags/${RELEASE}.tar.gz | tar -xz -C /opt/dashy --strip-components=1
    cd /opt/dashy
    npm install
    npm run build
    echo "${RELEASE}" > /opt/${APP}_version.txt
    msg_ok "Updated ${APP} to ${RELEASE}"

    msg_info "Restoring conf.yml"
    cd ~
    cp -R conf.yml /opt/dashy/user-data
    msg_ok "Restored conf.yml"

    msg_info "Cleaning"
    rm -rf conf.yml /opt/dashy/public/conf.yml
    msg_ok "Cleaned"

    msg_info "Starting ${APP}"
    systemctl start dashy
    msg_ok "Started ${APP}"
    msg_ok "Updated Successfully"
  else
    msg_ok "No update required. ${APP} is already at ${RELEASE}"
  fi
  exit
}

# Начало скрипта
start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${APP} should be reachable by going to the following URL: {BL}http://IP:4000{CL} \n"
