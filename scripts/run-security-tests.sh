#!/usr/bin/env bash
# The exit code is the number of failed tests.
set -euo pipefail

PASS=0
FAIL=0

# Prints the result of a test (code 0 = passed) and updates the counters.
check_test() {
    local name="$1"
    local result="$2"
    if [ "${result}" = "0" ]; then
        echo "  [PASS] ${name}"
        PASS=$((PASS + 1))
    else
        echo "  [FAIL] ${name}"
        FAIL=$((FAIL + 1))
    fi
}

echo "========================================================================"
echo "  AUTOMATED TEST SUITE — SECURE WIREGUARD VPN GATEWAY"
echo "========================================================================"

echo ""
echo "--- PHASE A: INITIAL ISOLATION & KILL SWITCH TESTS (VPN DOWN) ---"
docker exec vpn-client vpn-control down >/dev/null

# Test 1: the client reaches the server on the isolated LAN (must succeed)
if docker exec vpn-client ping -c 2 -W 2 192.168.57.1 >/dev/null 2>&1; then
    check_test "1. Isolated LAN connectivity (192.168.57.10 -> 192.168.57.1) without VPN" 0
else
    check_test "1. Isolated LAN connectivity (192.168.57.10 -> 192.168.57.1) without VPN" 1
fi

# Test 2: without the VPN, direct access to the WAN target must be blocked
if docker exec vpn-client ping -c 2 -W 2 172.28.0.100 >/dev/null 2>&1; then
    check_test "2. Kill Switch & isolation: direct Internet access blocked without VPN" 1
else
    check_test "2. Kill Switch & isolation: direct Internet access blocked without VPN" 0
fi

echo ""
echo "--- PHASE B: WIREGUARD TUNNEL ACTIVATION & FULL TUNNEL VALIDATION ---"
docker exec vpn-client vpn-control up >/dev/null
sleep 2

# Test 3: the client reaches the server's tunnel address (must succeed)
if docker exec vpn-client ping -c 2 -W 2 10.8.0.1 >/dev/null 2>&1; then
    check_test "3. Encrypted WireGuard tunnel established (10.8.0.2 -> 10.8.0.1)" 0
else
    check_test "3. Encrypted WireGuard tunnel established (10.8.0.2 -> 10.8.0.1)" 1
fi

# Test 4: Full Tunnel and NAT; the WAN target must see the server's address, 172.28.0.10
SEEN_IP=$(docker exec vpn-client curl -s --max-time 4 http://172.28.0.100/ip | tr -d '\r\n' || true)
if [ "${SEEN_IP}" = "172.28.0.10" ]; then
    check_test "4. Full Tunnel (0.0.0.0/0) & NAT MASQUERADE (public IP seen = ${SEEN_IP})" 0
else
    check_test "4. Full Tunnel (0.0.0.0/0) & NAT MASQUERADE (IP seen = '${SEEN_IP}', expected 172.28.0.10)" 1
fi

# Test 5: DNS leak; resolution must go through 10.8.0.1, inside the tunnel
RESOLVED_IP=$(docker exec vpn-client dig +short @10.8.0.1 wan-target.lab | tr -d '\r\n' || true)
if [ "${RESOLVED_IP}" = "172.28.0.100" ]; then
    check_test "5. DNS leak protection (resolution via 10.8.0.1 -> ${RESOLVED_IP})" 0
else
    check_test "5. DNS leak protection (resolution failed: '${RESOLVED_IP}')" 1
fi

# Test 6: IPv6 leak; IPv6 must be disabled on the client
IPV6_DISABLED=$(docker exec vpn-client cat /proc/sys/net/ipv6/conf/all/disable_ipv6 | tr -d '\r\n')
if [ "${IPV6_DISABLED}" = "1" ]; then
    check_test "6. IPv6 leak protection (net.ipv6.conf.all.disable_ipv6 = 1)" 0
else
    check_test "6. IPv6 leak protection" 1
fi

echo ""
echo "--- PHASE C: SECURITY AUDIT & HARDENING (BLUE TEAM) ---"

# Test 7: wg0.conf must be mode 600 on both the server and the client
PERM_SRV=$(docker exec vpn-server stat -c "%a" /etc/wireguard/wg0.conf)
PERM_CLI=$(docker exec vpn-client stat -c "%a" /etc/wireguard/wg0.conf)
if [ "${PERM_SRV}" = "600" ] && [ "${PERM_CLI}" = "600" ]; then
    check_test "7. Strict permissions on WireGuard keys and files (chmod 600)" 0
else
    check_test "7. Strict permissions on WireGuard files (Server=${PERM_SRV}, Client=${PERM_CLI})" 1
fi

# Test 8: SSH segmentation; reachable from management (192.168.56.50),
# blocked from the Client Lab (192.168.57.10)
SSH_MGMT_OK=1
if docker exec mgmt-admin nc -z -w 2 192.168.56.10 22 >/dev/null 2>&1; then
    SSH_MGMT_OK=0
fi
SSH_CLIENT_BLOCKED=0
if docker exec vpn-client nc -z -w 2 192.168.57.1 22 >/dev/null 2>&1; then
    SSH_CLIENT_BLOCKED=1
fi

if [ "${SSH_MGMT_OK}" = "0" ] && [ "${SSH_CLIENT_BLOCKED}" = "0" ]; then
    check_test "8. SSH segmentation (allowed on VMnet1 .56.10:22, blocked on VMnet2 .57.1:22)" 0
else
    check_test "8. SSH segmentation (MGMT_OK=${SSH_MGMT_OK}, CLIENT_BLOCKED=${SSH_CLIENT_BLOCKED})" 1
fi

echo ""
echo "========================================================================"
echo "  FINAL RESULT: ${PASS} TESTS PASSED / $((PASS + FAIL)) (${FAIL} FAILED)"
echo "========================================================================"
exit "${FAIL}"
