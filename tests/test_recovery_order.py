"""Offline state-machine test. Never touches Kindle or real process state."""
from pathlib import Path
import os, shutil, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
bash=Path(os.environ.get('ProgramFiles','C:/Program Files'))/'Git/bin/bash.exe'
if not bash.is_file(): bash=shutil.which('bash')
if not bash: raise SystemExit('Bash is required for this recovery test')
with tempfile.TemporaryDirectory(prefix='soundring-recovery-test-') as tmp:
    script=Path(tmp)/'test.sh'
    script.write_text('''#!/bin/bash
set -u
RUN="$2/run"; BASE="$2/base"; DATA="$2/data"; LOG="$2/log"
mkdir -p "$RUN" "$BASE" "$DATA/logs"
. "$1"
record_pid() { :; }; alive() { return 1; }; stop_app() { :; }; log() { :; }
release_lock() { [ -f "$RUN/recovery.done" ]; }
recover || exit 11
[ -f "$RUN/recovery.done" ] || exit 12
rm -f "$RUN/recovery.done" "$RUN/recovery.attempts"
release_lock() { return 1; }
if recover; then exit 13; fi
[ ! -f "$RUN/recovery.done" ] || exit 14
called=0
same_boot() { return 1; }
stop_app() { exit 15; }
release_lock() { called=1; return 0; }
recover || exit 16
[ "$called" = 1 ] && [ -f "$RUN/recovery.previous-boot" ] || exit 17
. "$1"
same_boot() { return 1; }
release_lock() { return 0; }
log() { :; }
sleep 30 & victim=$!
trap 'kill "$victim" 2>/dev/null || true' EXIT
record_pid "$RUN/app.pid" "$victim"
if alive "$RUN/app.pid";then exit 18;fi
recover || exit 19
kill -0 "$victim" 2>/dev/null || exit 20
kill "$victim" 2>/dev/null || true;wait "$victim" 2>/dev/null || true
trap - EXIT
''',encoding='utf8',newline='\n')
    subprocess.run([str(bash),script.as_posix(),(root/'launcher/session-common.sh').as_posix(),Path(tmp).as_posix()],check=True,timeout=20)
print('Recovery: completion marker precedes lock release and rolls back if release fails')
