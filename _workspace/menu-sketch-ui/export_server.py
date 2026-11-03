"""Receive Penpot's exported bytes on loopback; no design writes."""
from http.server import BaseHTTPRequestHandler,ThreadingHTTPServer
from pathlib import Path
import json,re
out=Path(__file__).resolve().parent/'exports';out.mkdir(exist_ok=True)
class Handler(BaseHTTPRequestHandler):
 def end_headers(self):
  self.send_header('Access-Control-Allow-Origin','*');self.send_header('Access-Control-Allow-Private-Network','true');super().end_headers()
 def do_OPTIONS(self):
  self.send_response(204);self.send_header('Access-Control-Allow-Headers','Content-Type');self.send_header('Access-Control-Allow-Methods','POST,OPTIONS');self.end_headers()
 def do_POST(self):
  name=self.path.removeprefix('/')
  if not re.fullmatch(r'[a-z0-9-]+\.png',name):self.send_error(400);return
  body=json.loads(self.rfile.read(int(self.headers['Content-Length'])));data=bytes(body['bytes'])
  if data[:8]!=b'\x89PNG\r\n\x1a\n':self.send_error(400);return
  (out/name).write_bytes(data);self.send_response(200);self.end_headers();self.wfile.write(b'{}')
 def log_message(self,*args):pass
ThreadingHTTPServer(('127.0.0.1',4410),Handler).serve_forever()
