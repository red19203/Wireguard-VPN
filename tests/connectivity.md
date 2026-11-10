# Test Report 1 — Connectivity & Full Tunnel (`0.0.0.0/0`)

## 1. Objective
Verify the client's initial isolation on the `192.168.57.0/24` segment before the VPN is enabled, then validate that the WireGuard tunnel (`10.8.0.0/24`) comes up and that all Internet traffic leaves through the server's NAT (`Full Tunnel`).

## 2. Procedure and Commands

### Step A: Initial state (VPN down)
```bash
# On VPN-CLIENT: bring the VPN down
vpn-control down

# 1. Reachability of the local gateway on VMnet2 (MUST SUCCEED)
ping -c 4 192.168.57.1

# 2. Access to the WAN / Internet (MUST FAIL)
ping -c 4 172.28.0.100
ping -c 4 1.1.1.1
```
**Observed result**: `192.168.57.1` replies (`0% packet loss`), while `172.28.0.100` and `1.1.1.1` are rejected (`Operation not permitted` / `Network is unreachable`).

### Step B: Full Tunnel state (VPN up)
```bash
# On VPN-CLIENT: bring the Full Tunnel up
vpn-control up

# 1. Check the handshake and the wg0 interface
wg show

# 2. Ping the server's internal address inside the tunnel (10.8.0.1)
ping -c 4 10.8.0.1

# 3. Check the source IP address seen by a target located on the WAN
curl -s http://172.28.0.100/json
```
**Observed result**:
```json
{
  "seen_source_ip": "172.28.0.10",
  "wan_target": "172.28.0.100",
  "full_tunnel_nat_verified": true
}
```
The source address seen on the WAN side is `172.28.0.10` (the WAN address of `VPN-SERVER`), which confirms that the client's traffic (`10.8.0.2`) goes entirely through the WireGuard tunnel and then through the server's NAT.
