#!/bin/bash
set -e
python3 /app/pzbot.py &
PID_BOT=$!
python3 /app/pzwatcher.py &
PID_WATCHER=$!
wait -n
kill $PID_BOT $PID_WATCHER 2>/dev/null
exit 1
