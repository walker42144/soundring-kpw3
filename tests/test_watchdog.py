from pathlib import Path
import os, shutil, subprocess, tempfile
root=Path(__file__).resolve().parents[1]
gitbash=Path(os.environ.get('ProgramFiles','C:/Program Files'))/'Git/bin/bash.exe'
shell=str(gitbash) if gitbash.is_file() else (shutil.which('bash') or shutil.which('sh'))
assert shell
watchdog=(root/'launcher/watchdog.sh').as_posix()
script=r'''. "$1"
watchdog_check 1 100 100; [ "$WD_HUNG" = 0 ] || exit 1
watchdog_check 1 100 279; [ "$WD_HUNG" = 0 ] || exit 2
watchdog_check 1 100 280; [ "$WD_HUNG" = 1 ] || exit 3
watchdog_check 1 101 281; [ "$WD_HUNG" = 0 ] || exit 4
watchdog_check 0 101 1000; [ "$WD_HUNG" = 0 ] || exit 5
watchdog_check 1 101 1001; [ "$WD_HUNG" = 0 ] || exit 6
watchdog_check 1 101 50; [ "$WD_HUNG" = 0 ] || exit 7
watchdog_check 1 bad 500; [ "$WD_HUNG" = 0 ] || exit 8
watchdog_check 1 101 bad; [ "$WD_HUNG" = 0 ] || exit 9
'''
subprocess.run([shell,'-c',script,'test',watchdog],check=True)
with tempfile.TemporaryDirectory() as tmp:
 run=Path(tmp);(run/'stock.fb').write_bytes(b'precious');(run/'logs').mkdir()
 common=(root/'launcher/session-common.sh').as_posix()
 script=r'''RUN="$1"; DATA="$1"; LOG="$1/logs/session.log"; . "$2"
record_pid(){ :; }; stop_app(){ :; }; alive(){ return 1; }; release_lock(){ return 1; }
recover && exit 10
[ ! -e "$RUN/recovery.done" ] || exit 11
[ -f "$RUN/stock.fb" ] || exit 12
exit 0
'''
 subprocess.run([shell,'-c',script,'test',run.as_posix(),common],check=True)
print('Watchdog: monotonic timeout, heartbeat recovery, sleep, clock rollback and failed lock recovery passed')
