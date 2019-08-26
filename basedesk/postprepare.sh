#!/bin/bash

set -xe

HOSTNAME=$(hostname)
NODENUM=2
echo "installing good packages"
pacman -Syu
pacman -S macchanger dnscrypt-proxy git --noconfirm



# get dotfiles
git init .
git remote add origin https://github.com/ripx80/dotfiles
git fetch
git reset --hard origin/master
git pull origin master


echo 'setting up wireguard'
pacman -S wireguard-arch wireguard-tools
cd /etc/wireguard
wg genkey > $HOSTNAME_private.key
chmod 600 $HOSTNAME_private.key
wg pubkey < $HOSTNAME_private.key > $HOSTNAME_public.key


cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
Address = 192.168.2.11/32
PrivateKey = [pivkey]
DNS = 192.168.2.1

[Peer]
PublicKey = <pubkey>
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = [ip:port]

EOF

systemctl enable wg-quick@wg0


echo "installing xorg"
pacman -S xorg-server --noconfirm

