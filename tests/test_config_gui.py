from pathlib import Path
import sys,tempfile,json,threading,urllib.request,urllib.parse,socket
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import config_gui as c
assert c.REDIRECT=='http://127.0.0.1:8765/callback'
for value in ['http://localhost:9876/callback','http://192.168.1.1:9876/callback','https://127.0.0.1:9876/callback','http://127.0.0.1:9876/cb?x=1','http://127.0.0.1/callback']:
    try: c.validate_redirect(value);raise AssertionError(value)
    except ValueError: pass
assert c.validate_redirect('http://127.0.0.1:9876/custom').path=='/custom'
with tempfile.TemporaryDirectory() as d:
    path=Path(d)/'config.json';c.write_json(path,{'lyrics_source':'lrclib'});assert json.loads(path.read_text(encoding='utf-8'))['lyrics_source']=='lrclib'
with socket.socket() as probe:
    probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
redirect=f'http://127.0.0.1:{port}/different-path'; captured={}
def launch(url):
    q=urllib.parse.parse_qs(urllib.parse.urlsplit(url).query);captured['redirect']=q['redirect_uri'][0]
    def callback():
        with urllib.request.urlopen(redirect+'?'+urllib.parse.urlencode({'state':q['state'][0],'code':'test-code'}),timeout=5) as r: assert r.status==200
    threading.Thread(target=callback,daemon=True).start();return True
class Response:
    def __enter__(self): return self
    def __exit__(self,*args): pass
    def read(self,*args): return b'{"access_token":"fake","refresh_token":"fake","expires_in":3600}'
def token(req,timeout):
    captured['post']=urllib.parse.parse_qs(req.data.decode());return Response()
c.webbrowser.open=launch;c.urlopen=token
result=c.authorize('fake-client',redirect)
assert result['redirect_uri']==redirect==captured['redirect']==captured['post']['redirect_uri'][0]
assert captured['post']['code']==['test-code']
print('Callback tests passed: validation, custom loopback port/path, PKCE callback and token request, atomic export.')
