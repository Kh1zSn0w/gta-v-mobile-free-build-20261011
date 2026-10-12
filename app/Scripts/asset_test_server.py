import http.server,socketserver,sys,pathlib,re
root=pathlib.Path(sys.argv[1]).resolve()
class Handler(http.server.BaseHTTPRequestHandler):
 def log_message(self,*args):pass
 def do_GET(self):
  path=(root/self.path.lstrip('/')).resolve()
  if not path.is_relative_to(root) or not path.is_file():self.send_error(404);return
  match=re.fullmatch(r'bytes=(\d+)-(\d+)',self.headers.get('Range',''))
  if not match:self.send_error(400);return
  size=path.stat().st_size;start,end=map(int,match.groups());end=min(end,size-1)
  if start>=size or end<start:self.send_error(416);return
  self.send_response(206);self.send_header('Content-Range',f'bytes {start}-{end}/{size}');self.send_header('Content-Length',str(end-start+1));self.end_headers()
  with path.open('rb') as stream:stream.seek(start);self.wfile.write(stream.read(end-start+1))
class LocalServer(http.server.ThreadingHTTPServer):
 def server_bind(self):
  # The fixture is loopback-only; hostname lookup is unnecessary and can stall CI DNS.
  socketserver.TCPServer.server_bind(self)
  self.server_name='localhost';self.server_port=self.server_address[1]
server=LocalServer(('127.0.0.1',0),Handler)
print(server.server_address[1],flush=True);server.serve_forever()
