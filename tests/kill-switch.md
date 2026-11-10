# Test Report 4 — Kill Switch Validation & Firewall Audit

## 1. Objective
Show that if the WireGuard tunnel (`wg0`) stops or fails, `VPN-CLIENT` immediately blocks any attempt to reach the Internet (`Fail-Closed`), so the client's real IP address is never exposed.

## 2. Reproducible test scenario

### Step 1: Tunnel up -> WAN access works
```bash
docker exec vpn-client vpn-control up
docker exec vpn-client curl -s http://172.28.0.100/ip
# Returns: 172.28.0.10
```

### Step 2: Tunnel down -> outbound traffic is blocked immediately
```bash
docker exec vpn-client vpn-control down
docker exec vpn-client ping -c 2 -W 2 172.28.0.100
# Returns: ping: sendmsg: Operation not permitted (100% packet loss)
```

### Step 3: WireGuard handshake traffic stays allowed
Even when the Kill Switch blocks all Internet traffic, the client may still send packets to `192.168.57.1:51820/UDP`, so the tunnel can be brought back up without touching the firewall:
```bash
docker exec vpn-client vpn-control up
docker exec vpn-client curl -s http://172.28.0.100/ip
# Returns 172.28.0.10 again
```

## 3. SSH segmentation audit (Management vs Client Lab)
```bash
# From the Management network (192.168.56.50) to 192.168.56.10:22 -> ALLOWED
docker exec mgmt-admin nc -zv 192.168.56.10 22

# From the Client Lab network (192.168.57.10) to 192.168.57.1:22 -> BLOCKED
docker exec vpn-client nc -zv -w 2 192.168.57.1 22
```
