#!/usr/bin/env bash
# UFW firewall configuration for VPN-SERVER (VMware, Ubuntu 24.04).
# Run as root. Note that 'ufw --force reset' erases any existing rules.
set -euo pipefail

# Interfaces are identified by IP address, since their names vary from VM to VM.
WAN_IF=$(ip -o -4 addr show | awk '!/127\.0\.0\.1|192\.168\.56\.|192\.168\.57\.|10\.8\.0\./ {print $2; exit}')
MGMT_IF=$(ip -o -4 addr show | awk '/192\.168\.56\./ {print $2; exit}')
LAB_IF=$(ip -o -4 addr show | awk '/192\.168\.57\./ {print $2; exit}')

echo "[UFW] Detected interfaces: WAN=${WAN_IF}, MGMT=${MGMT_IF}, LAB=${LAB_IF}"

# Default policy: everything is denied inbound and routed, except what is opened below.
ufw --force reset
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# 1. SSH only from the management network (VMnet1, 192.168.56.0/24)
ufw allow in on "${MGMT_IF}" from 192.168.56.0/24 to 192.168.56.10 port 22 proto tcp comment 'SSH Admin VMnet1 only'

# 2. WireGuard (UDP 51820) only from the Client Lab network (VMnet2, 192.168.57.0/24)
ufw allow in on "${LAB_IF}" from 192.168.57.0/24 to 192.168.57.1 port 51820 proto udp comment 'WireGuard Tunnel Entry'

# 3. Internal DNS (53, UDP and TCP) reachable only from inside the wg0 tunnel
ufw allow in on wg0 from 10.8.0.0/24 to 10.8.0.1 port 53 comment 'WireGuard internal DNS'

# 4. Routing allowed only from wg0 to the WAN
ufw route allow in on wg0 out on "${WAN_IF}" from 10.8.0.0/24 comment 'Full Tunnel Forward to WAN'

ufw --force enable
ufw status verbose
