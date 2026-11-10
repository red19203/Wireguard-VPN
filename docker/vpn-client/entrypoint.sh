#!/usr/bin/env bash
# VPN-CLIENT container initialization: isolated at first, then automatic VPN
# connection if AUTO_CONNECT_VPN is "true".
set -euo pipefail

echo "=================================================================="
echo "[VPN-CLIENT] Initializing the isolated client on VMnet2 (192.168.57.10/24)"
echo "=================================================================="

LAB_IF=$(ip -o -4 addr show | awk '/192\.168\.57\./ {print $2; exit}')
echo "[VPN-CLIENT] Isolated network interface detected: ${LAB_IF} (192.168.57.10/24)"

# 1. Initial state required by the specification (section 6): no default
#    gateway and no DNS until the tunnel is up.
ip route del default 2>/dev/null || true
echo "# Initial isolation: no DNS before the VPN is established" > /etc/resolv.conf

echo "[VPN-CLIENT] Initial state (BEFORE VPN): Gateway=NONE, DNS=NONE."

# 2. Wait (30 seconds at most) for the configuration produced by the server
for i in $(seq 1 30); do
    if [ -f /shared_wg/client_wg0.conf ]; then
        break
    fi
    sleep 1
done

# 3. The Kill Switch is applied in both cases; only the tunnel state differs.
if [ "${AUTO_CONNECT_VPN:-true}" = "true" ]; then
    /usr/local/bin/vpn-control up
else
    /usr/local/bin/vpn-control down
fi

tail -f /dev/null
