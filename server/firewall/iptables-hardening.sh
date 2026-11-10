#!/usr/bin/env bash
# /etc/wireguard/iptables-hardening.sh
# iptables rules for the WireGuard server: tunnel routing to the WAN, and NAT.
# Called by PostUp with "up" and by PostDown with "down" (see wg0.conf.template).
set -euo pipefail

ACTION="${1:-up}"
# Interfaces are looked up by address rather than by name, since names vary
# from one machine to another. The WAN is the first interface that belongs
# to neither the management network, the lab network nor the tunnel.
WAN_IF=$(ip -o -4 addr show | awk '!/127\.0\.0\.1|192\.168\.56\.|192\.168\.57\.|10\.8\.0\./ {print $2; exit}')
MGMT_IF=$(ip -o -4 addr show | awk '/192\.168\.56\./ {print $2; exit}')
LAB_IF=$(ip -o -4 addr show | awk '/192\.168\.57\./ {print $2; exit}')

if [ "${ACTION}" = "up" ]; then
    # Tunnel traffic may go out to the WAN; on the way back, only replies to
    # existing connections are accepted.
    iptables -A FORWARD -i wg0 -o "${WAN_IF}" -s 10.8.0.0/24 -j ACCEPT
    iptables -A FORWARD -i "${WAN_IF}" -o wg0 -d 10.8.0.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "${WAN_IF}" -j MASQUERADE
elif [ "${ACTION}" = "down" ]; then
    # Symmetric removal; "|| true" avoids a failure if a rule is already gone.
    iptables -D FORWARD -i wg0 -o "${WAN_IF}" -s 10.8.0.0/24 -j ACCEPT 2>/dev/null || true
    iptables -D FORWARD -i "${WAN_IF}" -o wg0 -d 10.8.0.0/24 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT 2>/dev/null || true
    iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o "${WAN_IF}" -j MASQUERADE 2>/dev/null || true
fi
