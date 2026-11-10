FROM ubuntu:24.04
# VPN client: WireGuard and iptables, plus the diagnostic tools used by the tests.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard wireguard-tools \
    iproute2 iptables iputils-ping curl dnsutils netcat-openbsd \
    net-tools tcpdump procps ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/wireguard && chmod 700 /etc/wireguard
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
# vpn-control is installed in the PATH so it can be called through docker exec.
COPY vpn-control.sh /usr/local/bin/vpn-control
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/vpn-control

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
