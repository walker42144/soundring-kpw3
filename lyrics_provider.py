"""LRCLIB provider: metadata lookup without storing account credentials."""
import json
from urllib.parse import urlencode
from urllib.request import Request, urlopen
from urllib.error import HTTPError

class LyricsError(Exception):
    pass

def fetch(track, artist, album, duration, opener=urlopen):
    if not track.strip() or not artist.strip() or not album.strip() or duration <= 0:
        raise ValueError('track, artist, album and duration are required')
    params = urlencode({'track_name': track, 'artist_name': artist, 'album_name': album, 'duration': round(duration)})
    req = Request('https://lrclib.net/api/get?' + params, headers={'User-Agent': 'SoundRing-KPW3/0.1 (personal music remote)', 'Accept':'application/json'})
    try:
        with opener(req, timeout=12) as response:
            raw = response.read(1024 * 1024 + 1)
            if len(raw) > 1024 * 1024:
                raise LyricsError('response too large')
            data = json.loads(raw)
    except HTTPError as e:
        if e.code == 404:
            return {'status': 'not_found'}
        raise LyricsError('lyrics server returned HTTP %s' % e.code) from e
    if data.get('instrumental'):
        return {'status':'instrumental'}
    if data.get('syncedLyrics'):
        return {'status':'synced', 'lrc': data['syncedLyrics'], 'source':'LRCLIB'}
    if data.get('plainLyrics'):
        return {'status':'plain', 'text':data['plainLyrics'], 'source':'LRCLIB'}
    return {'status':'not_found'}
