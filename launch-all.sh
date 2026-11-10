#!/usr/bin/env bash
# Entry point for the Docker deployment: rebuilds the infrastructure from scratch,
# then runs the security test suite.
set -euo pipefail

echo "========================================================================"
echo "  SECURE WIREGUARD VPN GATEWAY — AUTOMATED MULTI-CONTAINER DEPLOYMENT"
echo "========================================================================"

if ! command -v docker >/dev/null 2>&1; then
    echo "[ERROR] Docker is not installed or not in PATH."
    exit 1
fi

# Start from a clean state, volumes included, so the keys are regenerated.
echo "[1/4] Cleaning up any previous containers..."
docker-compose down -v --remove-orphans 2>/dev/null || true

echo "[2/4] Building the Ubuntu 24.04 images (VPN-SERVER, VPN-CLIENT, MGMT-ADMIN, WAN-TARGET)..."
docker-compose build

echo "[3/4] Starting the full infrastructure in the background..."
docker-compose up -d

# Give the server time to generate the keys and bring wg0 up.
echo "[4/4] Waiting for WireGuard key generation and tunnel setup (5 seconds)..."
sleep 5

echo ""
echo "Running the full security test suite (connectivity, Full Tunnel, DNS/IPv6 leak, Kill Switch)..."
bash ./scripts/run-security-tests.sh
