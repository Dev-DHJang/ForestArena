#!/usr/bin/env python3
"""이 폴더만 loopback에서 제공하는 미디어 검토 서버. 외부 공개하지 않는다."""
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import argparse,re
class Handler(SimpleHTTPRequestHandler):
 def end_headers(self):
  self.send_header('Access-Control-Allow-Origin','*')
  self.send_header('Cache-Control','no-cache')
  super().end_headers()
 def do_GET(self):
  p=Path(self.translate_path(self.path))
  rng=self.headers.get('Range')
  if rng and p.is_file():
   m=re.fullmatch(r'bytes=(\d+)-(\d*)',rng)
   if m:
    size=p.stat().st_size;start=int(m[1]);end=min(int(m[2]) if m[2] else size-1,size-1)
    if start>=size:self.send_error(416);return
    self.send_response(206);self.send_header('Content-Type',self.guess_type(str(p)));self.send_header('Content-Range',f'bytes {start}-{end}/{size}');self.send_header('Content-Length',str(end-start+1));self.send_header('Accept-Ranges','bytes');self.end_headers()
    with p.open('rb') as f:
     f.seek(start);remaining=end-start+1
     while remaining:
      data=f.read(min(65536,remaining))
      if not data:break
      self.wfile.write(data);remaining-=len(data)
    return
  super().do_GET()
if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--port',type=int,default=4471);args=parser.parse_args()
 print(f'미디어 검토: http://127.0.0.1:{args.port}/',flush=True)
 ThreadingHTTPServer(('127.0.0.1',args.port),partial(Handler,directory=str(Path(__file__).resolve().parent))).serve_forever()
