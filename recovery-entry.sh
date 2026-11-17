#!/bin/sh
# Name: SoundRing Recovery
# Author: SoundRing
# Icon: /mnt/us/soundring/package/app/assets/recovery-icon.png
# DontUseFBInk
# Keep recovery alive when requesting the stock Home app closes the Scriptlet.
if [ "${1:-}" != --recovery-worker ];then
 command -v setsid >/dev/null 2>&1 || exit 2
 setsid /bin/sh "$0" --recovery-worker </dev/null >/dev/null 2>&1 &
 exit 0
fi
DATA=/mnt/us/soundring
# Never restore framebuffer or power state while KDash owns its session.
LOG="$DATA/logs/session.log"
if [ -d /var/tmp/kdash-candidate/session.lock ]; then echo "$(date) recovery refused: KDash session lock present" >> "$LOG"; exit 3; fi
owner=$(cat /var/tmp/soundring/session.lock/run 2>/dev/null)
for RUN in /var/tmp/soundring/run.*; do
 [ -z "$owner" ] || [ "$RUN" = "$owner" ] || continue
 [ -f "$RUN/session-common.sh" ] || continue
 [ -f "$RUN/recovery.done" ] && continue
 . "$RUN/session-common.sh"
 if alive "$RUN/supervisor.pid" && [ ! -f "$RUN/stop.request" ]; then
  if [ ! -f "$RUN/app.pid" ];then log 'manual recovery skipped starting session';continue;fi
  if alive "$RUN/app.pid";then
   [ ! -f "$RUN/sleeping" ] || { log 'manual recovery skipped sleeping session';continue; }
   heartbeat=0;[ ! -r "$RUN/heartbeat" ] || read heartbeat < "$RUN/heartbeat"
   case "$heartbeat" in ''|*[!0-9]*) heartbeat=0;;esac
   now=$(date +%s)
   if [ "$heartbeat" -gt 0 ] && [ "$now" -ge "$heartbeat" ] && [ $((now-heartbeat)) -lt 30 ];then log 'manual recovery skipped healthy active session';continue;fi
  fi
 fi
 rm -f "$RUN/recovery.failed" "$RUN/recovery.attempts"
 : > "$RUN/stop.request"
 if alive "$RUN/supervisor.pid"; then kill -TERM "$p" 2>/dev/null || true; sleep 3; fi
 if alive "$RUN/supervisor.pid"; then kill -KILL "$p" 2>/dev/null || true; fi
 recover || log 'manual recovery incomplete'
done
# A crash between mkdir(session.lock) and publishing run has no owned recovery
# script. Only an explicit Recovery action may quarantine that empty lock.
lock=/var/tmp/soundring/session.lock
owner_path=$(cat "$lock/run" 2>/dev/null)
case "$owner_path" in /var/tmp/soundring/run.*) token=${owner_path#/var/tmp/soundring/run.}; case "$token" in ''|*[!a-zA-Z0-9]*) missing=0;; *) missing=0; [ -d "$owner_path" ] || missing=1;; esac;; '') missing=1;; *) missing=0;; esac
if [ -d "$lock" ] && [ "$missing" -eq 1 ];then
 live=0
 for RUN in /var/tmp/soundring/run.*;do
  [ -f "$RUN/session-common.sh" ] || continue
  . "$RUN/session-common.sh"
  if alive "$RUN/supervisor.pid" || alive "$RUN/recover.pid" || alive "$RUN/guard.pid" || alive "$RUN/app.pid" || alive "$RUN/power-control.pid" || alive "$RUN/power-monitor.pid";then live=1;fi
 done
 if [ "$live" -eq 0 ];then mv "$lock" "$lock.abandoned.$(date +%s)" 2>/dev/null || true;fi
fi
