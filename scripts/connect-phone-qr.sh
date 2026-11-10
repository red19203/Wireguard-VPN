#!/usr/bin/env bash
# Generates the smartphone configuration and displays it as a QR code, to be
# scanned with the WireGuard app.
# Usage: ./scripts/connect-phone-qr.sh <host-ip>
# The address must be that of the machine publishing port 51820/udp, reachable
# from the phone. The default value is the one from the project's original network.
set -euo pipefail
HOST_IP="${1:-192.168.1.36}"

echo "========================================================================"
echo "  WIREGUARD QR CODE GENERATION FOR SMARTPHONE (Endpoint: ${HOST_IP}:51820)"
echo "========================================================================"

# The script runs inside the container, where the smartphone keys are stored.
docker exec -i vpn-server bash -s "${HOST_IP}" << 'INNER_EOF'
HOST_IP="$1"
SERVER_PUB=$(cat /etc/wireguard/server_public.key)
PHONE_PRIV=$(cat /etc/wireguard/phone_private.key)
PHONE_PSK=$(cat /etc/wireguard/phone_preshared.psk)

cat > /etc/wireguard/phone_wg0.conf <<CONF
[Interface]
Address = 10.8.0.3/24
PrivateKey = ${PHONE_PRIV}
DNS = 10.8.0.1

[Peer]
PublicKey = ${SERVER_PUB}
PresharedKey = ${PHONE_PSK}
Endpoint = ${HOST_IP}:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
CONF
chmod 600 /etc/wireguard/phone_wg0.conf
qrencode -t ansiutf8 < /etc/wireguard/phone_wg0.conf
INNER_EOF
