# Test Report 2 — DNS Leak Protection

## 1. Objective
Ensure that no DNS query sent by `VPN-CLIENT` leaves in clear text on the local `192.168.57.0/24` network or towards a local ISP resolver, and that 100% of DNS resolutions go through the encrypted `wg0` tunnel to `10.8.0.1`.

## 2. Measures in place
1. **Before the VPN connects**: `/etc/resolv.conf` contains no DNS server and the Kill Switch blocks all UDP/TCP 53 packets on the physical interface `192.168.57.10`.
2. **While the VPN is connected**: `/etc/resolv.conf` is set exclusively to `nameserver 10.8.0.1`, which is the `dnsmasq` instance listening inside the `wg0` tunnel on `VPN-SERVER`.

## 3. Verification commands
```bash
# 1. Check the resolver configured on VPN-CLIENT
docker exec vpn-client cat /etc/resolv.conf
# Expected: nameserver 10.8.0.1

# 2. Test DNS resolution through the encrypted tunnel
docker exec vpn-client dig +short @10.8.0.1 wan-target.lab
# Expected: 172.28.0.100

# 3. Use tcpdump to check that no port 53 packet travels in clear text outside the tunnel
docker exec vpn-server timeout 3 tcpdump -ni any port 53
```
