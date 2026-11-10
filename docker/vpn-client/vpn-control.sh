#!/usr/bin/env bash
# VPN client control command: vpn-control {up|down|status}
set -euo pipefail

ACTION="${1:-status}"
LAB_IF=$(ip -o -4 addr show | awk '/192\.168\.57\./ {print $2; exit}')

# Kill Switch: everything is denied by default. Outside the tunnel, only ping to
# the gateway and the WireGuard flow (UDP 51820) are allowed on the LAN.
apply_kill_switch() {
    echo "[KILL-SWITCH] Enabling the strict Kill Switch firewall on VPN-CLIENT..."
    iptables -F
    iptables -X
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT DROP

    # Loopback and replies to connections that are already established
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # On the physical network (192.168.57.0/24), only:
    #   - ping to the gateway (192.168.57.1), useful for connectivity tests
    #   - WireGuard transport (UDP 51820) to that same address
    iptables -A OUTPUT -o "${LAB_IF}" -d 192.168.57.1/32 -p icmp -j ACCEPT
    iptables -A OUTPUT -o "${LAB_IF}" -d 192.168.57.1/32 -p udp --dport 51820 -j ACCEPT

    # Any other outbound traffic must go through the encrypted wg0 interface
    iptables -A OUTPUT -o wg0 -j ACCEPT
}

case "${ACTION}" in
    up)
        echo "[VPN-CLIENT] Starting the Full Tunnel (0.0.0.0/0)..."
        cp /shared_wg/client_wg0.conf /etc/wireguard/wg0.conf
        chmod 600 /etc/wireguard/wg0.conf
        # wg0 is set up by hand, which works in a container as well as in a VM
        ip link del dev wg0 2>/dev/null || true
        ip link add dev wg0 type wireguard
        ip address add 10.8.0.2/24 dev wg0
        wg setconf wg0 <(grep -vE '^(Address|DNS)' /etc/wireguard/wg0.conf)
        ip link set mtu 1420 up dev wg0
        # The WireGuard endpoint stays directly reachable; everything else goes through wg0
        ip route replace 192.168.57.1/32 dev "${LAB_IF}"
        ip route replace default dev wg0
        # DNS points to the VPN server only, to prevent any DNS leak
        echo "nameserver 10.8.0.1" > /etc/resolv.conf
        apply_kill_switch
        echo "[VPN-CLIENT] Tunnel wg0 UP. Default route: dev wg0 | DNS: 10.8.0.1"
        ;;
    down)
        echo "[VPN-CLIENT] Taking down tunnel wg0 (Kill Switch stays active)..."
        ip route del default dev wg0 2>/dev/null || true
        ip link del dev wg0 2>/dev/null || true
        # No DNS once the tunnel is down, so no query can leave outside the VPN
        echo "# VPN down - no active DNS server (Kill Switch)" > /etc/resolv.conf
        apply_kill_switch
        echo "[VPN-CLIENT] Tunnel wg0 DOWN. All direct Internet traffic is blocked."
        ;;
    status)
        echo "=== Interfaces ==="
        ip -br addr
        echo "=== Routing table ==="
        ip route
        echo "=== WireGuard state ==="
        wg show || true
        echo "=== Kill Switch rules (iptables OUTPUT) ==="
        iptables -L OUTPUT -v -n
        ;;
    *)
        echo "Usage: vpn-control {up|down|status}"
        exit 1
        ;;
esac
