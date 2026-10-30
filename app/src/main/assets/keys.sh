#!/system/bin/sh
# YouTube button on the Chromecast Remote without an accessibility helper, so held keys keep repeating.
# Based on docs/devices/tcl-55p71b-g09-key-repeat.md ("Both at once"). Runs as the shell user and does
# not survive a reboot; start it with start-keys.sh.
# The YouTube button arrives as KEY_UNKNOWN (0001 00f0) after MSC_SCAN 000c0077; Netflix sends the same
# key after 000c0078 and is answered by the system, so only the scancode tells them apart.
NAME='Chromecast Remote'
echo $$ > /data/local/tmp/keys.pid
find_dev() { getevent -p 2>/dev/null | grep -B1 "name: .*\"$NAME\"" | head -1 | sed 's/.*: //'; }
open_app() { am start -a android.intent.action.MAIN -c android.intent.category.LEANBACK_LAUNCHER -n "$1" >/dev/null 2>&1; }
while true; do
  DEV=$(find_dev)
  if [ -z "$DEV" ]; then sleep 5; continue; fi
  (
    SCAN=''
    getevent "$DEV" 2>/dev/null | while read -r line; do
      case "$line" in
        "0004 0004 "*) SCAN=${line#0004 0004 } ;;
        "0001 00f0 00000001"*)
          case "$SCAN" in
            000c0077*) open_app com.google.android.youtube.tv/com.google.android.apps.youtube.tv.activity.ShellActivity ;;
          esac ;;
      esac
    done
  ) &
  sleep 1
  # The remote's node is recreated when it sleeps and reconnects; reopen the new one.
  while true; do
    GP=$(pgrep -f "getevent $DEV" | head -1)
    [ -z "$GP" ] && break
    if ls -l /proc/$GP/fd 2>/dev/null | grep -q '(deleted)'; then kill $GP 2>/dev/null; break; fi
    NOW=$(find_dev)
    if [ -n "$NOW" ] && [ "$NOW" != "$DEV" ]; then kill $GP 2>/dev/null; break; fi
    sleep 3
  done
  wait
  sleep 2
done
