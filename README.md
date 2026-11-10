# Secure WireGuard VPN Gateway

WireGuard VPN gateway running a Full Tunnel (`0.0.0.0/0`) on Ubuntu 24.04 LTS, with a client-side Kill Switch and a three-network segmentation. The project focuses on secure network architecture and system hardening, from a Blue Team perspective.

Two deployment modes are provided:

1. **Docker** (`docker-compose.yml` and `launch-all.sh`): the whole infrastructure starts with a single command. The three isolated networks are reproduced, keys are generated on first start (permissions `600`), the tunnel is brought up, the Kill Switch is applied, and the 8 security tests then run.
2. **VMware Workstation or Raspberry Pi**: the repository provides the Netplan configurations (`server/netplan/`), the UFW and `iptables` rules (`server/firewall/`), the client Kill Switch (`client/wireguard/`) and a deployment script for Raspberry Pi (`scripts/deploy-raspberry-pi.sh`).

## Quick start (Docker)

```bash
chmod +x launch-all.sh
./launch-all.sh
```

Or step by step with Docker Compose:

```bash
docker compose up -d --build
bash ./scripts/run-security-tests.sh
```

## Security tests

`scripts/run-security-tests.sh` runs 8 checks in three phases:

- **Isolation and Kill Switch (VPN down)**: the client reaches the server on the isolated LAN but cannot reach the WAN target.
- **Tunnel and Full Tunnel (VPN up)**: ping to `10.8.0.1`, source address seen by the WAN target (`172.28.0.10`), DNS resolution through the tunnel, and IPv6 disabled.
- **Hardening**: `600` permissions on the `wg0.conf` files, and SSH reachable from management but blocked from the Client Lab.

The script returns the number of failed tests as its exit code. Detailed procedures are in `tests/`.

## Repository layout

```text
secure-wireguard-vpn-gateway/
├── README.md
├── .gitignore
├── docker-compose.yml
├── launch-all.sh
├── docker/
│   ├── vpn-server/
│   │   ├── Dockerfile
│   │   └── entrypoint.sh
│   ├── vpn-client/
│   │   ├── Dockerfile
│   │   ├── entrypoint.sh
│   │   └── vpn-control.sh
│   ├── mgmt-admin/
│   │   └── Dockerfile
│   └── wan-target/
│       ├── Dockerfile
│       └── server.py
├── server/
│   ├── netplan/
│   │   └── 01-vpn-server.yaml
│   ├── wireguard/
│   │   └── wg0.conf.template
│   └── firewall/
│       ├── 99-wireguard-security.conf
│       ├── ufw-rules.sh
│       └── iptables-hardening.sh
├── client/
│   └── wireguard/
│       ├── 01-vpn-client-netplan.yaml
│       ├── wg0.conf.template
│       └── kill-switch.sh
├── scripts/
│   ├── generate-keys.sh
│   ├── run-security-tests.sh
│   └── deploy-raspberry-pi.sh
├── tests/
│   ├── connectivity.md
│   ├── dns-leak.md
│   ├── ipv6-leak.md
│   └── kill-switch.md
└── documentation/
    ├── installation.md
    ├── configuration.md
    └── troubleshooting.md
```

## Useful commands (Docker)

Check the state of the tunnel and the Kill Switch on the client:

```bash
docker exec -it vpn-client vpn-control status
```

Bring the VPN down to observe the Kill Switch. The ping to the WAN target fails, the ping to the LAN gateway succeeds:

```bash
docker exec -it vpn-client vpn-control down
docker exec -it vpn-client ping -c 2 172.28.0.100
docker exec -it vpn-client ping -c 2 192.168.57.1
```

Restore the tunnel and check that traffic goes through the VPN server:

```bash
docker exec -it vpn-client vpn-control up
docker exec -it vpn-client curl http://172.28.0.100/json
```

## Documentation

The installation, configuration, Raspberry Pi deployment and troubleshooting guides are in `documentation/`.
