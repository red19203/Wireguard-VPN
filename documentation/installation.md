# Installation Guide — Docker & VMware Workstation (Ubuntu 24.04 LTS)

## Option A: Automated deployment with Docker containers (recommended for a quick test)

### 1. Prerequisites
* Docker Engine (24.0+) and Docker Compose v2 (`docker compose version`).
* Linux host, Windows (with WSL2 / Docker Desktop) or macOS.

### 2. One-command launch
From the root of the `secure-wireguard-vpn-gateway/` folder:

```bash
chmod +x launch-all.sh
./launch-all.sh
```

This script automatically:
1. Creates the 3 virtual networks (`wan_net`, `mgmt_net` `192.168.56.0/24`, and `client_lab_net` `192.168.57.0/24` with `internal: true`).
2. Builds the Ubuntu 24.04 LTS containers (`vpn-server`, `vpn-client`, `mgmt-admin`, `wan-target`).
3. Generates the private/public keys and the preshared key (`PresharedKey`) with `600` permissions.
4. Enables IPv4 routing, NAT (`MASQUERADE`), the `iptables` firewall and the Kill Switch.
5. Runs the 8 security validation tests.

## Option B: Step-by-step deployment in VMware Workstation

### 1. Virtual Network Editor configuration (VMware Workstation)
Open **Edit > Virtual Network Editor** as Administrator:
* **VMnet8**: Type **NAT**, DHCP **Enabled**, host adapter **Connected**.
* **VMnet1**: Type **Host-only**, subnet `192.168.56.0` / `255.255.255.0`, DHCP **Disabled**, host adapter **Connected**.
* **VMnet2**: Type **Host-only**, subnet `192.168.57.0` / `255.255.255.0`, DHCP **Disabled**, host adapter **Unchecked**.

### 2. Creating the virtual machines
* **VM 1: `VPN-SERVER`**
  * OS: Ubuntu Server 24.04 LTS | 2 vCPU | 2 GB RAM | 25 GB disk
  * NIC 1: `VMnet8` (NAT)
  * NIC 2: `VMnet1` (Host-only `192.168.56.0/24`)
  * NIC 3: `VMnet2` (Host-only `192.168.57.0/24`)
* **VM 2: `VPN-CLIENT`**
  * OS: Ubuntu Desktop 24.04 LTS | 2 vCPU | 4 GB RAM | 30 GB disk
  * NIC 1 (only): `VMnet2` (Host-only `192.168.57.0/24`)

### 3. Initial update and interface identification on `VPN-SERVER`
```bash
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y
sudo hostnamectl set-hostname vpn-server
ip -br link
ip -br addr
ip route
```
Adjust the interface names (`ens33`, `ens37`, `ens38`) in `server/netplan/01-vpn-server.yaml`, copy the file to `/etc/netplan/01-vpn-server.yaml`, run `sudo chmod 600 /etc/netplan/*.yaml`, then test with `sudo netplan try` before confirming with `sudo netplan apply`.
