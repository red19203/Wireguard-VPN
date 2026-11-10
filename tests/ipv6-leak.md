# Test Report 3 — IPv6 Leak Protection

## 1. Objective
In an IPv4 Full Tunnel configuration (`AllowedIPs = 0.0.0.0/0`), if the host or the local network advertises an IPv6 route (*Router Advertisement*), the client's operating system could send traffic to dual-stack sites over IPv6 **outside the VPN tunnel**.

## 2. Hardening measures
1. **Disabled at the Linux kernel level (`sysctl`)** on `VPN-SERVER` and `VPN-CLIENT`:
   ```ini
   net.ipv6.conf.all.disable_ipv6 = 1
   net.ipv6.conf.default.disable_ipv6 = 1
   net.ipv6.conf.lo.disable_ipv6 = 1
   ```
2. **Disabled in Netplan** (`dhcp6: false`, `accept-ra: false`).
3. **`ip6tables` policy set to `DROP`** in the `kill-switch.sh` script.

## 3. Verification commands
```bash
# 1. Check the kernel parameter on the client and the server
docker exec vpn-client cat /proc/sys/net/ipv6/conf/all/disable_ipv6
docker exec vpn-server cat /proc/sys/net/ipv6/conf/all/disable_ipv6
# Expected: 1

# 2. Check that there are no IPv6 addresses or routes at all
docker exec vpn-client ip -6 addr
docker exec vpn-client ip -6 route
# Expected: no output (empty)
```
