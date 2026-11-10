FROM ubuntu:24.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    iproute2 iputils-ping openssh-client netcat-openbsd curl dnsutils procps \
    && rm -rf /var/lib/apt/lists/*
CMD ["tail", "-f", "/dev/null"]
