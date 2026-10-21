"""Serve the official cached Penpot plugin on loopback with required CORS."""
from http.server import ThreadingHTTPServer,SimpleHTTPRequestHandler
import sys
from pathlib import Path
from urllib.parse import urlsplit
class Handler(SimpleHTTPRequestHandler):
 def end_headers(self):
  self.send_header('Access-Control-Allow-Origin','*')
  self.send_header('Cache-Control','no-store')
  self.send_header('Access-Control-Allow-Private-Network','true')
  super().end_headers()
 def do_GET(self):
  if urlsplit(self.path).path=='/plugin.js':
   source=(Path(sys.argv[1])/'plugin.js').read_text()
   source=source.replace('`?theme=${penpot.theme}`','`http://127.0.0.1:4400/index.html?theme=${penpot.theme}`').replace('hidden:!!mcp','hidden:false')
   data=('(()=>{const mcp=undefined;'+source+'\n})();').encode()
   self.send_response(200);self.send_header('Content-Type','application/javascript');self.send_header('Content-Length',str(len(data)));self.end_headers();self.wfile.write(data)
  else:super().do_GET()
 def do_OPTIONS(self):self.send_response(204);self.end_headers()
 def __init__(self,*args,**kwargs):super().__init__(*args,directory=sys.argv[1],**kwargs)
ThreadingHTTPServer(('127.0.0.1',4400),Handler).serve_forever()
