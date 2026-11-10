#!/usr/bin/env bash
# Installs and hardens a WireGuard server on Raspberry Pi OS (64-bit) or
# Ubuntu Server ARM64. Run from the repository root, as root.
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Run this script with sudo: sudo ./scripts/deploy-raspberry-pi.sh"
    exit 1
fi

echo "[1/6] Full system update of the Raspberry Pi..."
apt-get update && apt-get full-upgrade -y
apt-get install -y wireguard wireguard-tools ufw dnsmasq qrencode unattended-upgrades

echo "[2/6] Detecting the Raspberry Pi's main network interface..."
PI_IF=$(ip route show default | awk '/default/ {print $5; exit}')
PI_IP=$(ip -o -4 addr show dev "${PI_IF}" | awk '{split($4,a,"/"); print a[1]; exit}')
echo "Detected interface: ${PI_IF} (local IP: ${PI_IP})"

echo "[3/6] Applying kernel hardening with sysctl (IPv4 forwarding + IPv6 disabled)..."
cp ./server/firewall/99-wireguard-security.conf /etc/sysctl.d/99-wireguard-security.conf
sysctl --system

echo "[4/6] Generating cryptographic keys (umask 077, chmod 600)..."
umask 077
mkdir -p /etc/wireguard
chmod 700 /etc/wireguard

if [ ! -f /etc/wireguard/server_private.key ]; then
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
    wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key
    wg genpsk > /etc/wireguard/preshared.psk
fi

# Routing and NAT rules are embedded directly in PostUp and PostDown.
echo "[5/6] Creating /etc/wireguard/wg0.conf..."
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = $(cat /etc/wireguard/server_private.key)
PostUp = iptables -A FORWARD -i wg0 -o ${PI_IF} -s 10.8.0.0/24 -j ACCEPT; iptables -A FORWARD -i ${PI_IF} -o wg0 -d 10.8.0.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o ${PI_IF} -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -o ${PI_IF} -s 10.8.0.0/24 -j ACCEPT; iptables -D FORWARD -i ${PI_IF} -o wg0 -d 10.8.0.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT; iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o ${PI_IF} -j MASQUERADE

[Peer]
PublicKey = $(cat /etc/wireguard/client_public.key)
PresharedKey = $(cat /etc/wireguard/preshared.psk)
AllowedIPs = 10.8.0.2/32
EOF
chmod 600 /etc/wireguard/wg0.conf

echo "[6/6] Enabling the wg-quick@wg0 systemd service..."
systemctl enable --now wg-quick@wg0
echo "[OK] WireGuard server running on the Raspberry Pi (${PI_IP}:51820/UDP)."
echo "SECURITY REMINDER: only forward UDP port 51820 from your router to ${PI_IP}. Never expose SSH (22/TCP) or any web interface to the Internet."
