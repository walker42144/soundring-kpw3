#!/bin/sh
set -eu
BASE=/mnt/us/soundring
mkdir -p "$BASE/logs"
setsid /bin/sh "$BASE/package/launcher/kdash-launch.sh" </dev/null >>"$BASE/logs/bootstrap.log" 2>&1 &
