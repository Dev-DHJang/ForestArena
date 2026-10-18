from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import base64, json, re
ROOT = Path(__file__).resolve().parents[2]
TASK = ROOT / "_workspace/forestlight-video-reference-v06"
ASSETS = ROOT / "assets/ui/forestlight-video-reference-v06"
class Handler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(ASSETS), **kwargs)
    def log_message(self, fmt, *args):
        print(fmt % args, flush=True)
    def end_headers(self):
        self.send_header("Access-Control-Allow-Origin", "https://design.penpot.app")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.send_header("Access-Control-Allow-Private-Network", "true")
        super().end_headers()
    def do_GET(self):
        if self.path == "/bundle.json":
            data = (TASK / "bundle.json").read_bytes()
        elif self.path == "/media.json":
            data = json.dumps({"base64": base64.b64encode((ASSETS / "background-forest-v06.png").read_bytes()).decode()}).encode()
        else:
            return super().do_GET()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.end_headers()
        self.wfile.write(data)
    def do_POST(self):
        name = self.path.rsplit("/", 1)[-1]
        size = int(self.headers.get("Content-Length", "0"))
        if not re.fullmatch(r"[A-Za-z0-9_.-]+\.(png|json|svg)", name) or not 0 < size < 30000000:
            return self.send_error(400)
        payload = self.rfile.read(size)
        if self.path.startswith("/export/"):
            data = bytes(json.loads(payload)["bytes"])
            if not data.startswith(b"\x89PNG\r\n\x1a\n"):
                return self.send_error(415)
            target = TASK / "exports"
        elif self.path.startswith("/record/"):
            data = json.dumps(json.loads(payload), ensure_ascii=False, indent=2).encode()
            target = TASK
        else:
            return self.send_error(404)
        target.mkdir(exist_ok=True)
        (target / name).write_bytes(data)
        self.send_response(201)
        self.end_headers()
        self.wfile.write(b"saved")
    def do_OPTIONS(self):
        print('Preflight origin:', self.headers.get('Origin'), flush=True)
        self.send_response(204)
        self.end_headers()
ThreadingHTTPServer(("127.0.0.1", 4433), Handler).serve_forever()
