#!/usr/bin/env bash

# Derived from http://stackoverflow.com/a/7453411/4863574

mkdir -p "$HOME/tmp"
PIDFILE="$HOME/tmp/dump_to_s3.pid"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LOGFILE=/var/log/dump_to_s3/dump_to_s3.log

if [ -e "${PIDFILE}" ] && (ps -u $(whoami) -opid= |
                           grep -P "^\s*$(cat ${PIDFILE})$" &> /dev/null); then
  echo "dump_to_s3 Already running. Exiting"
  exit 99
fi

cd "$DIR"
"$DIR/dump_to_s3.bash" >> "$LOGFILE" 2>&1 &
echo $! > "${PIDFILE}"
chmod 644 "${PIDFILE}"
