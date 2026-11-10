#!/usr/bin/env bash
# Generates WireGuard keys locally, in the directory given as argument
# (./generated-configs by default). If 'wg' is not installed on the host, the
# script fetches the configurations from the vpn-server container instead.
set -euo pipefail

OUT_DIR="${1:-./generated-configs}"
umask 077
mkdir -p "${OUT_DIR}"
chmod 700 "${OUT_DIR}"

if ! command -v wg >/dev/null 2>&1; then
    echo "[INFO] 'wg' is not installed on the host, using the vpn-server container to get the keys..."
    docker exec vpn-server cat /etc/wireguard/wg0.conf > "${OUT_DIR}/server-wg0.conf"
    docker exec vpn-server cat /shared_wg/client_wg0.conf > "${OUT_DIR}/client-wg0.conf"
    chmod 600 "${OUT_DIR}/server-wg0.conf" "${OUT_DIR}/client-wg0.conf"
    echo "[OK] Configurations extracted to ${OUT_DIR}/ (permissions 600)."
    exit 0
fi

wg genkey | tee "${OUT_DIR}/server_private.key" | wg pubkey > "${OUT_DIR}/server_public.key"
wg genkey | tee "${OUT_DIR}/client_private.key" | wg pubkey > "${OUT_DIR}/client_public.key"
wg genpsk > "${OUT_DIR}/preshared.psk"
chmod 600 "${OUT_DIR}"/*.key "${OUT_DIR}"/*.psk

echo "[OK] Key pairs and preshared key generated in ${OUT_DIR}/ with permissions 600."
