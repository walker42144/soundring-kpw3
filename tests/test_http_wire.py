from pathlib import Path
from http.server import BaseHTTPRequestHandler,HTTPServer
import threading,tempfile,subprocess,os,shutil,json
root=Path(__file__).resolve().parents[1];gitbash=Path(os.environ.get('ProgramFiles','C:/Program Files'))/'Git/bin/bash.exe';shell=str(gitbash) if gitbash.is_file() else (shutil.which('bash') or shutil.which('sh'));received=[]
class Handler(BaseHTTPRequestHandler):
 def do_PUT(self):
  n=int(self.headers.get('Content-Length','0'));received.append((self.headers.get('Content-Type'),self.rfile.read(n)));self.send_response(204);self.end_headers()
 def log_message(self,*args):pass
server=HTTPServer(('127.0.0.1',0),Handler);threading.Thread(target=server.serve_forever,daemon=True).start()
with tempfile.TemporaryDirectory() as t:
 t=Path(t);script=t/'build.lua';script.write_text("""package.path=arg[1]..'/?.lua;'..package.path
local h=require('services.http').new({runner={},storage={},dir=arg[2],curl='curl'})
local p={};for _,n in ipairs({'script','out','headers','err','rc','status','done','pid','cancel','worker'})do p[n]=arg[2]..'/'..n end
local text=h:build_script({url=arg[3],method='PUT',headers={['Content-Type']='application/json'},body='{"uris":["spotify:track:second"]}'},p)
local f=assert(io.open(p.script,'wb'));f:write(text);f:close()
""",encoding='utf8')
 subprocess.run(['luajit',str(script),root.as_posix(),t.as_posix(),f'http://127.0.0.1:{server.server_port}/play'],check=True)
 subprocess.run([shell,(t/'script').as_posix()],check=True,timeout=15)
 assert received==[('application/json',b'{"uris":["spotify:track:second"]}')],received
server.shutdown();print('Wire test: actual generated curl script sends the selected URI as JSON')
