from pathlib import Path
import json,sys,tempfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from config_gui import recover_lyric_choices
with tempfile.TemporaryDirectory() as tmp:
 root=Path(tmp);(root/'documents').mkdir();base=root/'soundring';base.mkdir();cache=base/'lyrics-cache';cache.mkdir();path=base/'lyric-choices.json';path.write_text('{bad',encoding='utf8')
 (cache/'abc.json').write_text(json.dumps({'version':1,'track_id':'abc','source':'qq','lrc':'[00:01] a','choice':{'source':'qq','id':'mid1'}}),encoding='utf8')
 (cache/'wrong.json').write_text(json.dumps({'version':1,'track_id':'other','source':'qq','lrc':'[00:01] a','choice':{'source':'qq','id':'mid1'}}),encoding='utf8')
 (cache/'broken.json').write_text(json.dumps({'version':1,'track_id':'broken','source':'netease','lrc':'not timed','choice':{'source':'netease','id':'2'}}),encoding='utf8')
 count,backup=recover_lyric_choices(root);assert count==1 and Path(backup).read_text()=='{bad';assert json.loads(path.read_text())=={'abc':{'source':'qq','id':'mid1'}}
 try:recover_lyric_choices(root);raise AssertionError('valid record must be preserved')
 except ValueError:pass
with tempfile.TemporaryDirectory() as tmp:
 root=Path(tmp);(root/'documents').mkdir();base=root/'soundring';base.mkdir();(base/'lyrics-cache').mkdir();path=base/'lyric-choices.json';path.write_text('{bad')
 try:recover_lyric_choices(root);raise AssertionError('empty recovery must not overwrite')
 except ValueError:assert path.read_text()=='{bad'
print('Choice recovery: validated cache only, original backed up, valid/empty cases preserved')
