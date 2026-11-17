from pathlib import Path
import subprocess,tempfile,shutil,os
root=Path(__file__).resolve().parents[1]
gitbash=Path(os.environ.get('ProgramFiles','C:/Program Files'))/'Git/bin/bash.exe'
shell=str(gitbash) if gitbash.is_file() else (shutil.which('bash') or shutil.which('sh'))
if not shell: raise RuntimeError('A POSIX shell is required for launcher tests')
lines=(root/'launcher/kdash-launch.sh').read_text(encoding='utf8').splitlines()
read=next(x for x in lines if x.startswith('limit=$(tr '));check=next(x for x in lines if x.startswith('case "$limit" in'))
with tempfile.TemporaryDirectory() as tmp:
 p=Path(tmp)/'session-limit'
 for data,want in [(b'600\n',0),(b'600\r\n',0),(b'180\n',0),(b'0\n',0),(b'garbage\n',2)]:
  p.write_bytes(data)
  script='log(){ :; }; PKG="$1"; '+read+'; '+check
  r=subprocess.run([shell,'-c',script,'test',tmp.replace('\\','/')],capture_output=True)
  assert r.returncode==want,(data,r.returncode,want)
print('Launcher: actual session-limit file accepts LF/CRLF and rejects invalid input')

assert (root/'session-limit').read_bytes()==b'0\n', 'device setting must default to unlimited with LF'
assert "tr -d '\\r'" in read, 'launcher must strip CR from Windows files'
