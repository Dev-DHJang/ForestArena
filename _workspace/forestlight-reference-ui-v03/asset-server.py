from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
from pathlib import Path
import base64,json,re
ROOT=Path(__file__).resolve().parents[2]
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*a,**k):super().__init__(*a,directory=str(ROOT/'assets/ui/forestlight-reference-v03'),**k)
 def end_headers(self):
  self.send_header('Access-Control-Allow-Origin','https://design.penpot.app')
  self.send_header('Access-Control-Allow-Methods','GET, POST, OPTIONS')
  self.send_header('Access-Control-Allow-Headers','Content-Type, Authorization')
  self.send_header('Access-Control-Allow-Private-Network','true')
  super().end_headers()
 def do_GET(self):
  if self.path=='/media.json':
   data=json.dumps({'base64':base64.b64encode((ROOT/'assets/ui/forestlight-reference-v03/background-lobby.png').read_bytes()).decode()}).encode()
   self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(data)
  else:super().do_GET()
 def do_POST(self):
  name=self.path.removeprefix('/export/')
  size=int(self.headers.get('Content-Length','0'))
  if not self.path.startswith('/export/') or not re.fullmatch(r'[A-Za-z0-9_.-]+\.png',name) or not 0<size<25000000:
   self.send_error(400);return
  try:data=bytes(json.loads(self.rfile.read(size))['bytes'])
  except Exception:self.send_error(400);return
  if not data.startswith(b'\x89PNG\r\n\x1a\n'):self.send_error(415);return
  out=ROOT/'_workspace/forestlight-reference-ui-v03/exports';out.mkdir(exist_ok=True)
  (out/name).write_bytes(data)
  self.send_response(201);self.end_headers();self.wfile.write(b'saved')
 def do_OPTIONS(self):
  print('Request origin:',self.headers.get('Origin'),'Requested headers:',self.headers.get('Access-Control-Request-Headers'),flush=True)
  self.send_response(204);self.end_headers()
ThreadingHTTPServer(('127.0.0.1',4430),Handler).serve_forever()
