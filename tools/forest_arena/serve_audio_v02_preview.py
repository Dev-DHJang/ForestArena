#!/usr/bin/env python3
"""Serve only the local preview folder, with HTTP byte ranges for audio seeking."""
from __future__ import annotations
import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import re

DEFAULT=Path(__file__).resolve().parents[2]/'assets/audio/v02-preview'


class PreviewHandler(SimpleHTTPRequestHandler):
    def send_head(self):
        self.remaining=None
        path=Path(self.translate_path(self.path))
        # Do not follow a symlink outside the selected preview folder.
        if not path.resolve().is_relative_to(Path(self.directory).resolve()):
            self.send_error(403);return None
        if path.is_dir():
            if self.path.split('?',1)[0].rstrip('/')=='':
                path=path/'preview.html'
            else:
                self.send_error(404);return None
        if not path.resolve().is_relative_to(Path(self.directory).resolve()):
            self.send_error(403);return None
        try: f=path.open('rb')
        except OSError:
            self.send_error(404);return None
        size=path.stat().st_size
        start,end=0,size-1
        requested=self.headers.get('Range')
        if requested:
            m=re.fullmatch(r'bytes=(\d*)-(\d*)',requested)
            if not m or not any(m.groups()):
                f.close();self.send_error(416);return None
            a,b=m.groups()
            if a:
                start=int(a);end=min(int(b),end) if b else end
            else:
                start=max(0,size-int(b))
            if start>=size or end<start:
                f.close();self.send_response(416);self.send_header('Content-Range',f'bytes */{size}')
                self.send_header('Content-Length','0');self.end_headers();return None
        self.send_response(206 if requested else 200)
        self.send_header('Content-Type',self.guess_type(str(path)))
        self.send_header('Accept-Ranges','bytes')
        self.send_header('Content-Length',str(end-start+1))
        self.send_header('Cache-Control','no-cache')
        if requested: self.send_header('Content-Range',f'bytes {start}-{end}/{size}')
        self.end_headers();f.seek(start);self.remaining=end-start+1
        return f

    def copyfile(self,source,output):
        while self.remaining and self.remaining>0:
            block=source.read(min(self.remaining,64*1024))
            if not block: break
            try: output.write(block)
            except (BrokenPipeError,ConnectionResetError): break
            self.remaining-=len(block)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port',type=int,default=8875)
    parser.add_argument('--directory',type=Path,default=DEFAULT)
    args=parser.parse_args()
    if not (args.directory/'preview.html').is_file(): parser.error('Preview folder must contain preview.html')
    server=ThreadingHTTPServer(('127.0.0.1',args.port),partial(PreviewHandler,directory=str(args.directory.resolve())))
    print(f'Preview only: http://127.0.0.1:{args.port}/preview.html',flush=True)
    try: server.serve_forever()
    except KeyboardInterrupt: pass
    finally: server.server_close()


if __name__=='__main__': main()
