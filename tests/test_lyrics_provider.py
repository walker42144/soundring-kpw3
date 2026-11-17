from pathlib import Path
import sys, io, json
from urllib.error import HTTPError
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from lyrics_provider import fetch, LyricsError
class R:
    def __init__(self, obj): self.raw=json.dumps(obj).encode()
    def __enter__(self): return self
    def __exit__(self,*args): pass
    def read(self,n): return self.raw
captured=[]
def op(req,timeout):
    captured.append(req.full_url)
    return R({'syncedLyrics':'[00:01.00] Hello', 'plainLyrics':'Hello'})
assert fetch('Song & Test','Artist','Album',285,op)['status']=='synced'
assert 'Song+%26+Test' in captured[0] and 'duration=285' in captured[0]
assert fetch('x','y','z',1,lambda *a,**k:R({'instrumental':True}))['status']=='instrumental'
assert fetch('x','y','z',1,lambda *a,**k:R({'plainLyrics':'text'}))['status']=='plain'
def missing(*a,**k): raise HTTPError('https://lrclib.net',404,'no',{},None)
assert fetch('x','y','z',1,missing)['status']=='not_found'
print('LRCLIB provider: URL encoding, synced/plain/instrumental and 404 passed')
