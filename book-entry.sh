#!/bin/sh
# Name: SoundRing Candidate
# Author: SoundRing
# Icon: /mnt/us/soundring/package/app/assets/cover-soundring.png
# DontUseFBInk
BASE=/mnt/us/soundring
mkdir -p "$BASE/logs" || exit 1
if ! command -v setsid >/dev/null 2>&1; then
 echo 'setsid unavailable; GUI unchanged' >> "$BASE/logs/bootstrap.log"; exit 2
fi
setsid /bin/sh "$BASE/package/launcher/kdash-launch.sh" </dev/null >> "$BASE/logs/bootstrap.log" 2>&1 &
exit 0
