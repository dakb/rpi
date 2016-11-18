#!/bin/bash

# exit immediately if a command/pipeline exits with a non-zero status
set -e
set -o pipefail

# initial root check
if [[ "$EUID" -ne 0 ]]; then
  echo "Run this script as root" 1>&2
  exit 1
fi

# set variables
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
packages="htop tcpdump iotop rsync dnsutils bc"
services="hciuart.service bluetooth.service avahi-daemon.service fake-hwclock.service ntp.service"

#update and upgrade via apt
apt-get update
apt-get -y upgrade

#install additional packages
apt-get -y install $packages

#disable few services
systemctl disable $services

#create and mount ramdisk
mkdir /ramdisk
cat >> /etc/fstab <<EOF

# ramdisk
tmpfs   /ramdisk  tmpfs nodev,nosuid,size=128M  0 0
EOF

mount -a -t tmpfs

# delete and link apt cache
rm -rf /var/cache/apt/archives
ln -s /ramdisk /var/cache/apt/archives
echo "[i]apt archive linked to ramdisk"

# persistently disable swap
swapoff --all
apt-get -y remove dphys-swapfile
echo "[-]swap disabled"

# .bashrc setup
rm -rf /root/.bashrc
cp -p $DIR/scripts/.bashrc /root/.bashrc

# blacklist modules
. $DIR/scripts/bl.sh

# chrony setup
. $DIR/scripts/chrony.sh

# ssh setup
. $DIR/scripts/ssh.sh

# change from graphical.target (default) to multi-user.target
if [[ $(systemctl get-default) != "multi-user.target" ]]; then
  systemctl set-default multi-user.target
fi

#cleaning via apt
apt-get autoclean
apt-get -y autoremove
echo "[i]apt clean, unused packages removed"

#done, restart
shutdown -r now
