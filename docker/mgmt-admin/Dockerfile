FROM ubuntu:24.04
# Admin workstation: network clients only (SSH, ping, nc, dig, curl).
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2 iputils-ping openssh-client netcat-openbsd curl dnsutils procps \
    && rm -rf /var/lib/apt/lists/*
# Keep the container running so commands can be run in it with docker exec.
CMD ["tail", "-f", "/dev/null"]
