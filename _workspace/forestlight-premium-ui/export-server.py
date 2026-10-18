"""로컬 Penpot PNG 전달용. localhost만 수신하고 작업 폴더에만 쓴다."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent/'exports'
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(ROOT),**kwargs)
 def end_headers(self):
  self.send_header('Access-Control-Allow-Origin','https://design.penpot.app')
  self.send_header('Access-Control-Allow-Methods','GET, POST, OPTIONS')
  self.send_header('Access-Control-Allow-Headers','Content-Type')
  self.send_header('Access-Control-Allow-Private-Network','true')
  super().end_headers()
 def do_OPTIONS(self):self.send_response(204);self.end_headers()
 def do_POST(self):
  m=re.fullmatch(r'/exports/([A-Za-z0-9_.-]+\.png)',self.path)
  n=int(self.headers.get('Content-Length','0'))
  if not m or not 8<n<30_000_000:self.send_error(400);return
  data=self.rfile.read(n)
  if not data.startswith(b'\x89PNG\r\n\x1a\n'):self.send_error(415);return
  OUT.mkdir(exist_ok=True);(OUT/m[1]).write_bytes(data)
  self.send_response(201);self.end_headers();self.wfile.write(b'saved')
if __name__=='__main__':ThreadingHTTPServer(('127.0.0.1',4425),Handler).serve_forever()
