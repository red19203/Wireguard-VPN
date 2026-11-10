# Troubleshooting Guide

## 1. The WireGuard handshake does not complete (`latest handshake` missing in `wg show`)
* **Common causes**:
  1. The client cannot reach the server's physical address `192.168.57.1`.
  2. Port `51820/UDP` is blocked by the server or client firewall.
  3. `PublicKey` and `PrivateKey` are swapped in `wg0.conf`.
* **Diagnostic commands**:
  ```bash
  # On the client: check connectivity to the endpoint
  ping -c 3 192.168.57.1
  # On the server: watch UDP 51820 packets arrive in real time
  sudo tcpdump -ni any udp port 51820
  ```

## 2. The handshake succeeds (`10.8.0.1` answers ping) but the client has no Internet access
* **Common causes**:
  1. IPv4 forwarding (`net.ipv4.ip_forward=1`) is not enabled on `VPN-SERVER`.
  2. The `MASQUERADE` NAT rule targets the wrong WAN interface name (for example `ens33` hard-coded while the interface is called `eth0` or `enp0s3`).
  3. The `iptables` or UFW `FORWARD` chain blocks traffic between `wg0` and the WAN interface.
* **Diagnostic commands on `VPN-SERVER`**:
  ```bash
  sysctl net.ipv4.ip_forward
  sudo iptables -t nat -L POSTROUTING -v -n
  sudo iptables -L FORWARD -v -n
  ```

## 3. IP addresses respond (`ping 1.1.1.1` works) but domain names fail
* **Common causes**:
  1. The client's `/etc/resolv.conf` does not point to `10.8.0.1` (or `resolvconf` / `systemd-resolved` is not installed to handle the `DNS = 10.8.0.1` directive from `wg-quick`).
  2. The `VPN-SERVER` firewall blocks port `53/UDP` on the `wg0` interface.
* **Diagnostic commands on `VPN-CLIENT`**:
  ```bash
  cat /etc/resolv.conf
  dig +short @10.8.0.1 ubuntu.com
  ```

## 4. SSH connection lost when applying Netplan or UFW
* **Required precautions**:
  * Always use `sudo netplan try` (it rolls back automatically after 120 seconds if the connection is lost) before `sudo netplan apply`.
  * Always explicitly allow port `22/TCP` on the `192.168.56.10` interface (`VMnet1`) **before** running `ufw enable` or `iptables -P INPUT DROP`.
