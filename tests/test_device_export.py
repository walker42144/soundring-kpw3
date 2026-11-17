from pathlib import Path
import sys,tempfile,json
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from config_gui import export_device_config
with tempfile.TemporaryDirectory() as d:
 root=Path(d);(root/'documents').mkdir();target=root/'soundring';target.mkdir();(target/'soundring-config.json').write_text('old config');(target/'soundring-token.json').write_text('old token');(target/'untouched').write_text('keep')
 paths,backup=export_device_config(d,{'source':'qq'},{'refresh_token':'fake'});assert not Path(backup).is_relative_to(target);assert json.loads(Path(paths[0]).read_text())['source']=='qq';assert Path(backup,'soundring-config.json').read_text()=='old config';assert Path(backup,'soundring-token.json').read_text()=='old token';assert (target/'untouched').read_text()=='keep'
with tempfile.TemporaryDirectory() as d:
 try: export_device_config(d,{},{});raise AssertionError('missing documents')
 except ValueError: pass
print('Device config export: root validation, narrow backup and unrelated-file preservation passed')
import config_gui as module
with tempfile.TemporaryDirectory() as d:
 root=Path(d);(root/'documents').mkdir();target=root/'soundring';target.mkdir();a=target/'soundring-config.json';b=target/'soundring-token.json';a.write_text('original cfg');b.write_text('original token')
 original=module.write_json;calls=[]
 def failing(path,value):
  calls.append(path)
  if len(calls)==2: raise OSError('simulated failure')
  return original(path,value)
 module.write_json=failing
 try:
  try: module.export_device_config(d,{'new':1},{'new':2});raise AssertionError('failure expected')
  except OSError: pass
  assert a.read_text()=='original cfg' and b.read_text()=='original token'
 finally: module.write_json=original
print('Device config export: rollback after partial write passed')
