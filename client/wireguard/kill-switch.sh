#!/usr/bin/env bash

set -euo pipefail

LAB_IF=$(ip -o -4 addr show | awk '/192\.168\.57\./ {print $2; exit}')

iptables -F
iptables -X
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT DROP

# Loopback and replies to connections that are already established
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# On the physical network, only ping and UDP 51820 to 192.168.57.1 are allowed
iptables -A OUTPUT -o "${LAB_IF}" -d 192.168.57.1/32 -p icmp -j ACCEPT
iptables -A OUTPUT -o "${LAB_IF}" -d 192.168.57.1/32 -p udp --dport 51820 -j ACCEPT

# Application traffic is only allowed through the encrypted wg0 interface
iptables -A OUTPUT -o wg0 -j ACCEPT

# IPv6 is blocked entirely
if command -v ip6tables >/dev/null 2>&1; then
    ip6tables -P INPUT DROP 2>/dev/null || true
    ip6tables -P FORWARD DROP 2>/dev/null || true
    ip6tables -P OUTPUT DROP 2>/dev/null || true
fi

echo "[KILL-SWITCH] Rules applied successfully on ${LAB_IF} and wg0."
