#!/usr/bin/env python3
# Minimal HTTP server that returns the source IP address it sees.
# It is used to check the Full Tunnel: behind the VPN server's NAT, the client
# must appear with the address 172.28.0.10.
from http.server import BaseHTTPRequestHandler, HTTPServer
import json

# Routes: / and /ip (plain text), /json (details and result of the NAT check).
class EchoIPHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        client_ip = self.client_address[0]
        if self.path in ("/", "/ip"):
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            self.wfile.write(f"{client_ip}\n".encode("utf-8"))
        elif self.path == "/json":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            payload = {
                "seen_source_ip": client_ip,
                "wan_target": "172.28.0.100",
                "full_tunnel_nat_verified": (client_ip == "172.28.0.10")
            }
            self.wfile.write((json.dumps(payload, indent=2) + "\n").encode("utf-8"))
        else:
            self.send_response(404)
            self.end_headers()

    # Request logging is disabled to keep the container output readable.
    def log_message(self, format, *args):
        return

if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", 80), EchoIPHandler)
    print("[wan-target] Listening on 0.0.0.0:80 (Echo IP endpoint)")
    server.serve_forever()
