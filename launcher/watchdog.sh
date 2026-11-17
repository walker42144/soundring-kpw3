#!/bin/sh
# State machine for an unchanged heartbeat. Input: eligible, heartbeat, uptime.
# Caller keeps WD_LAST, WD_SINCE; no wall clock or process signals here.
watchdog_check() {
 WD_HUNG=0
 case "$1:$2:$3" in 1:*:* ) ;; *) WD_LAST=;WD_SINCE=;return;; esac
 case "$2" in ''|*[!0-9]*) WD_LAST=;WD_SINCE=;return;; esac
 case "$3" in ''|*[!0-9]*) WD_LAST=;WD_SINCE=;return;; esac
 if [ "$2" != "${WD_LAST:-}" ] || [ -z "${WD_SINCE:-}" ] || [ "$3" -lt "$WD_SINCE" ];then WD_LAST=$2;WD_SINCE=$3;return;fi
 if [ $(( $3 - WD_SINCE )) -ge 180 ];then WD_HUNG=1;fi
}
