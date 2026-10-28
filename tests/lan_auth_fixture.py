"""Test-only internal auth fixture. Production always uses API + PostgreSQL."""
import json
import os
import re
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
receipt_lock = threading.Lock()
class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_args): pass
    def do_POST(self):
        data = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        token = data.get("access_token")
        if token == "slow-host":
            time.sleep(0.3)
            token = "host"
        status = 401
        result = {"error": "invalid_token"}
        if self.path == "/internal/v1/lan/auth" and self.headers.get("x-forest-arena-service-token") == "lan-runtime-test-service":
            if token in ("host", "guest", "third"):
                status = 200
                result = {"player_id": token, "nickname": {"host": "호스트숲", "guest": "손님숲", "third": "셋째숲"}[token]}
            elif token == "unnamed": status, result = 409, {"error": "nickname_required"}
        if self.headers.get("x-forest-arena-service-token") == "lan-runtime-test-service" and (self.path == "/internal/v1/lan/rooms" or re.fullmatch(r"/internal/v1/lan/matches/[0-9a-f-]+/(register|result)", self.path)):
            status, result = 200, {"status": "stored"}
            path = os.environ.get('FOREST_ARENA_LAN_TEST_RECEIPTS')
            if path:
                with receipt_lock, open(path, 'a') as receipt:
                    receipt.write(json.dumps({'route': self.path, 'payload': data}) + '\n')
        body = json.dumps(result).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try: self.wfile.write(body)
        except BrokenPipeError: pass
ThreadingHTTPServer(("127.0.0.1", int(os.environ.get("FOREST_ARENA_LAN_TEST_API_PORT", "18081"))), Handler).serve_forever()
