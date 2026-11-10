#!/usr/bin/env bash
set -euo pipefail

echo "=================================================================="
echo "[VPN-SERVER] Initializing the WireGuard gateway (Ubuntu 24.04)"
echo "=================================================================="

WAN_IF=$(ip -o -4 addr show | awk '/172\.28\.0\./ {print $2; exit}')
MGMT_IF=$(ip -o -4 addr show | awk '/192\.168\.56\./ {print $2; exit}')
LAB_IF=$(ip -o -4 addr show | awk '/192\.168\.57\./ {print $2; exit}')

echo "[VPN-SERVER] Detected interfaces:"
echo "  - WAN  (VMnet8 / 172.28.0.10)   : ${WAN_IF}"
echo "  - MGMT (VMnet1 / 192.168.56.10) : ${MGMT_IF}"
echo "  - LAB  (VMnet2 / 192.168.57.1)  : ${LAB_IF}"

ip route del default 2>/dev/null || true
ip route add default via 172.28.0.1 dev "${WAN_IF}"

umask 077
mkdir -p /etc/wireguard /shared_wg /etc/dnsmasq.d
chmod 700 /etc/wireguard /shared_wg

if [ ! -f /etc/wireguard/server_private.key ]; then
    echo "[VPN-SERVER] Generating WireGuard key pairs..."
    wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
    wg genkey | tee /etc/wireguard/client_private.key | wg pubkey > /etc/wireguard/client_public.key
    wg genpsk > /etc/wireguard/preshared.psk
    # Additional peer for the smartphone (10.8.0.3/32)
    wg genkey | tee /etc/wireguard/phone_private.key | wg pubkey > /etc/wireguard/phone_public.key
    wg genpsk > /etc/wireguard/phone_preshared.psk
    chmod 600 /etc/wireguard/*.key /etc/wireguard/*.psk
fi

SERVER_PRIV=$(cat /etc/wireguard/server_private.key)
SERVER_PUB=$(cat /etc/wireguard/server_public.key)
CLIENT_PRIV=$(cat /etc/wireguard/client_private.key)
CLIENT_PUB=$(cat /etc/wireguard/client_public.key)
PSK=$(cat /etc/wireguard/preshared.psk)
PHONE_PRIV=$(cat /etc/wireguard/phone_private.key)
PHONE_PUB=$(cat /etc/wireguard/phone_public.key)
PHONE_PSK=$(cat /etc/wireguard/phone_preshared.psk)

# Server configuration, with one peer for the client and one for the smartphone.
cat > /etc/wireguard/wg0.conf <<EOF
[Interface]
Address = 10.8.0.1/24
ListenPort = 51820
PrivateKey = ${SERVER_PRIV}
SaveConfig = false

# Peer 1: VPN-CLIENT (10.8.0.2/32)
[Peer]
PublicKey = ${CLIENT_PUB}
PresharedKey = ${PSK}
AllowedIPs = 10.8.0.2/32

# Peer 2: smartphone (10.8.0.3/32)
[Peer]
PublicKey = ${PHONE_PUB}
PresharedKey = ${PHONE_PSK}
AllowedIPs = 10.8.0.3/32
EOF
chmod 600 /etc/wireguard/wg0.conf

# Client configuration, dropped in the shared volume that the client container reads at startup.
cat > /shared_wg/client_wg0.conf <<EOF
[Interface]
Address = 10.8.0.2/24
PrivateKey = ${CLIENT_PRIV}
DNS = 10.8.0.1

[Peer]
PublicKey = ${SERVER_PUB}
PresharedKey = ${PSK}
Endpoint = 192.168.57.1:51820
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 25
EOF
chmod 600 /shared_wg/client_wg0.conf

# wg0 is created by hand rather than with wg-quick, which fails in a container
# (resolvconf and sysctl are unavailable). The wg-quick-specific directives are
# stripped before the file is passed to wg setconf.
ip link del dev wg0 2>/dev/null || true
ip link add dev wg0 type wireguard
ip address add 10.8.0.1/24 dev wg0
wg setconf wg0 <(grep -vE '^(Address|SaveConfig|PostUp|PostDown)' /etc/wireguard/wg0.conf)
ip link set mtu 1420 up dev wg0

# dnsmasq only listens on wg0 and the loopback. It forwards to 1.1.1.1 and 9.9.9.9
# and resolves two lab hostnames locally.
pkill dnsmasq 2>/dev/null || true
cat > /etc/dnsmasq.d/wg-dns.conf <<EOF
interface=wg0
listen-address=127.0.0.1,10.8.0.1
bind-interfaces
no-resolv
server=1.1.1.1
server=9.9.9.9
address=/wan-target.lab/172.28.0.100
address=/vpn-gateway.lab/10.8.0.1
EOF
dnsmasq --conf-file=/etc/dnsmasq.d/wg-dns.conf --user=root

# sshd only listens on the management address.
sed -i 's/^#*ListenAddress.*/ListenAddress 192.168.56.10/' /etc/ssh/sshd_config
grep -q "^ListenAddress 192.168.56.10" /etc/ssh/sshd_config || echo "ListenAddress 192.168.56.10" >> /etc/ssh/sshd_config
/usr/sbin/sshd

# Firewall: restrictive inbound and forward policy, then targeted openings.
iptables -F
iptables -t nat -F
iptables -X

iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# SSH and ping only from the management network (192.168.56.0/24)
iptables -A INPUT -i "${MGMT_IF}" -s 192.168.56.0/24 -p tcp --dport 22 -j ACCEPT
iptables -A INPUT -i "${MGMT_IF}" -s 192.168.56.0/24 -p icmp -j ACCEPT

# From the Client Lab (192.168.57.0/24): ping and UDP 51820 only
iptables -A INPUT -i "${LAB_IF}" -s 192.168.57.0/24 -d 192.168.57.1 -p icmp --icmp-type echo-request -j ACCEPT
iptables -A INPUT -i "${LAB_IF}" -s 192.168.57.0/24 -d 192.168.57.1 -p udp --dport 51820 -j ACCEPT

iptables -A INPUT -p udp --dport 51820 -j ACCEPT
ip route replace 192.168.1.0/24 via 192.168.56.1 2>/dev/null || true

# Internal services reachable from the tunnel: DNS and ping
iptables -A INPUT -i wg0 -s 10.8.0.0/24 -d 10.8.0.1 -p udp --dport 53 -j ACCEPT
iptables -A INPUT -i wg0 -s 10.8.0.0/24 -d 10.8.0.1 -p tcp --dport 53 -j ACCEPT
iptables -A INPUT -i wg0 -s 10.8.0.0/24 -d 10.8.0.1 -p icmp -j ACCEPT

# Tunnel routing to the WAN with outbound NAT
iptables -A FORWARD -i wg0 -o "${WAN_IF}" -s 10.8.0.0/24 -j ACCEPT
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "${WAN_IF}" -j MASQUERADE

echo "[VPN-SERVER] Gateway operational (Client Lab 10.8.0.2 and smartphone 10.8.0.3 ready)."
wg show

tail -f /dev/null
