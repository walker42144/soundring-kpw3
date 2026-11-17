from pathlib import Path
import json,sys,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from config_gui import scan_automatic_lyrics,remove_automatic_lyrics
def entry(track,choice=None):return {'version':1,'track_id':track,'source':'qq','lrc':'[00:01] song','choice':choice}
with tempfile.TemporaryDirectory() as tmp:
 root=Path(tmp);(root/'documents').mkdir();base=root/'soundring';base.mkdir();cache=base/'lyrics-cache';cache.mkdir();index=base/'lyric-choices.json';index.write_text(json.dumps({'chosen':{'source':'qq','id':'mid'}}))
 for name,data in [('auto',entry('auto')),('chosen',entry('chosen')),('manual',entry('manual',{'source':'qq','id':'m'}))]: (cache/(name+'.json')).write_text(json.dumps(data))
 (cache/'invalid.json').write_text('{broken')
 plan=scan_automatic_lyrics(root);assert len(plan['files'])==1 and plan['files'][0][0].endswith('auto.json')
 index.write_text('{}')
 try:remove_automatic_lyrics(plan);raise AssertionError('changed index accepted')
 except ValueError:pass
 assert (cache/'auto.json').exists()
 index.write_text(json.dumps({'chosen':{'source':'qq','id':'mid'}}));plan=scan_automatic_lyrics(root);assert remove_automatic_lyrics(plan)==1
 assert all((cache/(name+'.json')).exists() for name in ['chosen','manual','invalid'])
 index.write_text('{bad')
 try:scan_automatic_lyrics(root);raise AssertionError('corrupt choices accepted')
 except ValueError:pass
print('Cache cleanup: explicit automatic files only; protects manual, malformed and changed index')
