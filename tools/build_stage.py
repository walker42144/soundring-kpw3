"""Create an isolated staging tree; never touch a connected Kindle."""
from pathlib import Path
import json, os, shutil, struct, sys, tempfile
ROOT=Path(__file__).resolve().parents[1]
WORK=ROOT.parent

def build():
    stage=Path(tempfile.mkdtemp(prefix='soundring-stage-',dir=WORK))
    package=stage/'soundring'/'package';app=package/'app';app.mkdir(parents=True)
    for part in ['soundring','core','platform','ui','services','assets']:
        shutil.copytree(ROOT/part,app/part,ignore=shutil.ignore_patterns('__pycache__','*.pyc','*.pgm'))
    shutil.copy2(ROOT/'main.lua',app/'main.lua')
    for part in ['launcher','runtime']: shutil.copytree(ROOT/part,package/part)
    shutil.copy2(ROOT/'session-limit',package/'session-limit')
    shutil.copytree(ROOT/'licenses',package/'licenses')
    (package/'runtime'/'coverconv-c').unlink(missing_ok=True)
    (stage/'documents').mkdir()
    shutil.copy2(ROOT/'book-entry.sh',stage/'documents'/'SoundRing Candidate.sh')
    shutil.copy2(ROOT/'recovery-entry.sh',stage/'documents'/'SoundRing Recovery.sh')
    for entry in (stage/'documents').glob('*.sh'):
        if os.name != 'nt': entry.chmod(0o755)
    shutil.copytree(ROOT/'extension',stage/'extensions'/'soundring')
    runtime=package/'runtime'/'coverconv';data=runtime.read_bytes()
    if data[:4]!=b'\x7fELF' or data[4]!=1 or struct.unpack_from('<H',data,18)[0]!=40: raise RuntimeError('converter is not ARM32 ELF')
    phoff=struct.unpack_from('<I',data,28)[0];size,count=struct.unpack_from('<HH',data,42)
    if any(struct.unpack_from('<I',data,phoff+i*size)[0]==3 for i in range(count)):raise RuntimeError('converter is dynamically linked')
    json.loads((stage/'extensions'/'soundring'/'menu.json').read_text(encoding='utf8'))
    forbidden={'soundring-token.json','soundring-config.json','lyric-choices.json'}
    if any(p.name in forbidden for p in stage.rglob('*')): raise RuntimeError('private runtime data found')
    print(stage)
if __name__=='__main__':build()
