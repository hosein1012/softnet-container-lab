#!/bin/bash
set -euo pipefail

HOSTNAME=$(hostname)
CFG_DIR="/etc/nodes"
CFG_FILE="${CFG_DIR}/${HOSTNAME}.cfg"

echo "=== Node entrypoint: ${HOSTNAME} ==="

if [[ ! -f "${CFG_FILE}" ]]; then
    echo "[FATAL] Configuration file missing: ${CFG_FILE}"
    exit 1
fi

echo "[INFO] Loading config: ${CFG_FILE}"
source "${CFG_FILE}"

ip link set lo up
echo "[OK] Loopback interface up"

if [[ "${ROLE}" == "router" ]]; then
    ip link set eth1 up
    ip link set eth2 up

    # Flush only global addresses; keep IPv6 link-local addresses for NDP
    ip -4 addr flush dev eth1 2>/dev/null || true
    ip -4 addr flush dev eth2 2>/dev/null || true
    ip -6 addr flush dev eth1 scope global 2>/dev/null || true
    ip -6 addr flush dev eth2 scope global 2>/dev/null || true

    ip addr add "${NODE_IP}/${NODE_PREFIX}" dev eth1
    ip addr add "${NODE_IP2}/${NODE_PREFIX2}" dev eth2

    ip -6 addr add "${NODE_IP6}/${NODE_PREFIX6}" dev eth1 nodad
    ip -6 addr add "${NODE_IP6_2}/${NODE_PREFIX6_2}" dev eth2 nodad

    ip -6 route replace fc00:1::/64 dev eth1
    ip -6 route replace fc00:2::/64 dev eth2

    sysctl -w net.ipv4.ip_forward=1
    sysctl -w net.ipv6.conf.all.forwarding=1
    sysctl -w net.ipv6.conf.eth1.forwarding=1
    sysctl -w net.ipv6.conf.eth2.forwarding=1

    echo "[OK] Router configured"

else
    ip link set eth1 up

    # Flush only global addresses; keep IPv6 link-local addresses for NDP
    ip -4 addr flush dev eth1 2>/dev/null || true
    ip -6 addr flush dev eth1 scope global 2>/dev/null || true

    ip addr add "${NODE_IP}/${NODE_PREFIX}" dev eth1
    ip -6 addr add "${NODE_IP6}/${NODE_PREFIX6}" dev eth1 nodad

    ip route replace default via "${GW_IP}" dev eth1
    ip -6 route replace default via "${GW_IP6}" dev eth1

    echo "[OK] Host configured"
fi

echo ""
echo "[INFO] Network configuration:"
ip addr show
echo ""

echo "[INFO] Routes:"
ip route show
ip -6 route show
echo ""

echo "[INFO] Node ${HOSTNAME} ready"
