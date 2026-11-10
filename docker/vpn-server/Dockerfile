FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    wireguard wireguard-tools \
    iproute2 iptables iputils-ping curl dnsmasq openssh-server \
    net-tools tcpdump procps qrencode ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/run/sshd /etc/wireguard /etc/dnsmasq.d && chmod 700 /etc/wireguard
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 51820/udp 22/tcp
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
