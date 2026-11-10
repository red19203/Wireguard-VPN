FROM ubuntu:24.04
# Minimal image: Python for the HTTP server, network tools for diagnostics.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 iproute2 iputils-ping netcat-openbsd ca-certificates \
    && rm -rf /var/lib/apt/lists/*
COPY server.py /usr/local/bin/server.py
RUN chmod +x /usr/local/bin/server.py
EXPOSE 80
CMD ["python3", "/usr/local/bin/server.py"]
