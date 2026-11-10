# Configuration Reference — WireGuard, Firewall & Kill Switch

## 1. Kernel hardening (`server/firewall/99-wireguard-security.conf`)
* `net.ipv4.ip_forward = 1`: lets the Linux kernel on `VPN-SERVER` route IPv4 packets arriving from the `wg0` tunnel interface (`10.8.0.0/24`) to the WAN interface.
* `net.ipv6.conf.all.disable_ipv6 = 1` and `net.ipv6.conf.default.disable_ipv6 = 1`: fully disable the IPv6 stack on the server and the client, removing any risk of IPv6 traffic leaking outside the IPv4 tunnel.
* `net.ipv4.conf.all.rp_filter = 1`: enables reverse path filtering against IP spoofing.

## 2. Key generation and protection
WireGuard relies on Curve25519 for key exchange, ChaCha20-Poly1305 for authenticated encryption and BLAKE2s for hashing. A symmetric preshared key (`PresharedKey`) is added as an extra symmetric layer:

```bash
umask 077
wg genkey | tee server_private.key | wg pubkey > server_public.key
wg genkey | tee client_private.key | wg pubkey > client_public.key
wg genpsk > preshared.psk
chmod 600 *.key *.psk /etc/wireguard/wg0.conf
```

## 3. Client Full Tunnel configuration (`AllowedIPs = 0.0.0.0/0`)
On `VPN-CLIENT`, the `AllowedIPs = 0.0.0.0/0` directive in the `[Peer]` section tells WireGuard and the Linux routing table that **all IPv4 destinations** must be encrypted and sent through `wg0`, with the sole exception of UDP `51820` packets addressed to the physical endpoint `192.168.57.1`.

## 4. Server firewall and NAT (`server/firewall/iptables-hardening.sh` & `ufw-rules.sh`)
* **Administration segmentation**: port `22/TCP` (SSH) is only allowed inbound on the Management interface (`192.168.56.0/24`). Any SSH attempt from `192.168.57.0/24` (Client Lab) or from the WAN is dropped (`DROP`).
* **Client Lab segmentation (`192.168.57.0/24`)**: no `FORWARD` rule allows `192.168.57.0/24` to reach the WAN. Only inbound port `51820/UDP` to `192.168.57.1` is open, to receive the encrypted WireGuard packets.
* **Outbound NAT (`MASQUERADE`)**:
  ```bash
  iptables -A FORWARD -i wg0 -o "${WAN_IF}" -s 10.8.0.0/24 -j ACCEPT
  iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "${WAN_IF}" -j MASQUERADE
  ```
  Replaces the client's source address `10.8.0.2` with the server's WAN address when a packet leaves for the Internet.

## 5. Client Kill Switch (`client/wireguard/kill-switch.sh`)
Even if the `wg0` tunnel drops accidentally or is stopped manually, the `iptables -P OUTPUT DROP` policy on `VPN-CLIENT` immediately blocks every packet leaving through the physical interface `192.168.57.10`, except the WireGuard handshake flow (`UDP 51820` to `192.168.57.1`) and the diagnostic ping to `192.168.57.1`.
