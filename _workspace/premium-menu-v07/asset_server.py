from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import urlsplit,unquote
import json,re,base64
ROOT=Path(__file__).resolve().parents[2]
TASK=ROOT/'_workspace/premium-menu-v07'
class Handler(SimpleHTTPRequestHandler):
 def __init__(self,*a,**kw):super().__init__(*a,directory=str(ROOT),**kw)
 def log_message(self,*a):
  with (TASK/'asset-server-requests.log').open('a') as f:f.write(str(self.command)+' '+str(self.path)+' origin='+str(self.headers.get('Origin'))+' request_headers='+str(self.headers.get('Access-Control-Request-Headers'))+' private='+str(self.headers.get('Access-Control-Request-Private-Network'))+'\n')
 def end_headers(self):
  self.send_header('Access-Control-Allow-Origin','https://design.penpot.app')
  self.send_header('Access-Control-Allow-Methods','GET, POST, OPTIONS')
  self.send_header('Access-Control-Allow-Headers',self.headers.get('Access-Control-Request-Headers','Content-Type'))
  self.send_header('Access-Control-Allow-Credentials','true')
  self.send_header('Access-Control-Allow-Private-Network','true')
  super().end_headers()
 def do_GET(self):
  if self.path.startswith('/media/') and self.path.endswith('.json'):
   key=self.path.split('/')[-1].removesuffix('.json')
   if key in ['character-room','accessory-workshop','shop-market','archive','social-lodge','observatory']:
    path=ROOT/'assets/ui/premium-menu-v07/backgrounds'/f'{key}-v07.png'
   elif key in ['ja-hyun','myo-ryung','nabi','yu-ran']:
    path=TASK/'approved-source'/f'{key}-concept-v01.png'
   else:return self.send_error(404)
   data=json.dumps({'base64':base64.b64encode(path.read_bytes()).decode()}).encode()
   self.send_response(200);self.send_header('Content-Type','application/json');self.end_headers();self.wfile.write(data)
  elif self.path.startswith('/_workspace/premium-menu-v07/') or self.path.startswith('/assets/ui/premium-menu-v07/'):
   resolved=(ROOT/unquote(urlsplit(self.path).path).lstrip('/')).resolve()
   if not (resolved.is_relative_to(TASK) or resolved.is_relative_to(ROOT/'assets/ui/premium-menu-v07')):return self.send_error(403)
   return super().do_GET()
  else:return self.send_error(404)
 def do_OPTIONS(self):self.send_response(204);self.end_headers()
 def do_POST(self):
  name=self.path.rsplit('/',1)[-1];size=int(self.headers.get('Content-Length','0'))
  if not re.fullmatch(r'[A-Za-z0-9_.-]+\.(png|json|svg)',name) or not 0<size<100000000:return self.send_error(400)
  payload=self.rfile.read(size)
  if self.path.startswith('/export/'):
   data=bytes(json.loads(payload)['bytes']);target=TASK/'exports'
   if not data.startswith(b'\x89PNG\r\n\x1a\n'):return self.send_error(415)
  elif self.path.startswith('/record/'):
   data=json.dumps(json.loads(payload),ensure_ascii=False,indent=2).encode();target=TASK
  else:return self.send_error(404)
  target.mkdir(exist_ok=True);(target/name).write_bytes(data)
  self.send_response(201);self.end_headers();self.wfile.write(b'saved')
ThreadingHTTPServer(('127.0.0.1',4434),Handler).serve_forever()
