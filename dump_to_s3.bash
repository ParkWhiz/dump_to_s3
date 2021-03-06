#!/usr/bin/env bash

# http://stackoverflow.com/questions/59895/can-a-bash-script-tell-what-directory-its-stored-in
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPT_DIR/conf.bash

DATE_FMT="%Y-%m-%dT%H:%M:%S"

declare -A SECONDS_PER_UNIT=( ["H"]=$[60 * 60] ["D"]=$[60 * 60 * 24] ["W"]=$[60 * 60 * 24 * 7] )
declare -A RETENTION=( ["H"]="$HOURS_RETAINED" ["D"]="$DAYS_RETAINED" ["W"]="$WEEKS_RETAINED" )

log () {
  echo "$(date) - $1"
}

s3_bucket_path () {
  echo "s3://$BUCKET_NAME"
}

s3_key_path () {
  echo "$(s3_bucket_path)/$1"
}

to_seconds () {
  echo `date --date="$1" "+%s"`
}

time_diff () {
  # $1 is this hour's timestamp
  # $2 is a past timestamp
  # $3 is the units that we're interested in. One of "H", "D", "W" for 
  #    hour, day, week respectively
  echo $[ ( $(to_seconds "$1") - $(to_seconds "$2") ) / ${SECONDS_PER_UNIT["$3"]} ]
}

get_key_if_should_be_removed () {
  # $1 is the line provided by aws s3 ls
  # $2 is This hour's timestamp
  # $3 is the units that we're interested in. One of "H", "D", "W" for 
  #    hour, day, week respectively
  # If this key should be removed, echos filename. Otherwise, does nothing
  KEY_NAME=$(echo "$1" | tr -s " " | cut -d " " -f 4)
  BACKUP_TYPE=$(echo "$KEY_NAME" | cut -d "_" -f 2)
  OLD_TIMESTAMP=$(echo "$KEY_NAME" | cut -d "_" -f 3)
  if [[ $BACKUP_TYPE == $3 && $(time_diff "$2" "$OLD_TIMESTAMP" "$3") -gt ${RETENTION["$3"]} ]]; then
    echo "$KEY_NAME"
  fi
}

remove_old_entries () {
  # $1 is this hour's timestamp
  # $2 is the units that we're interested in. One of "H", "D", "W" for 
  #    hour, day, week respectively
  aws s3 ls "$(s3_bucket_path)" | while read -r LINE; do
    TO_REMOVE=$(get_key_if_should_be_removed "$LINE" "$1" "$2")
    if [[ "$TO_REMOVE" ]]; then
      aws s3 rm $(s3_key_path "$TO_REMOVE")
    fi
  done
}

NOW=$(date "+$DATE_FMT")
HOUR=$((10#`date --date=$NOW +%H`))
DOW=$((10#`date --date=$NOW +%u`))
DAY=$((10#`date --date=$NOW +%d`))

# Make backup
DUMP_FILE_NAME=/tmp/$KEY_PREFIX\_$NOW
log "DUMPING DB TO $DUMP_FILE_NAME"
eval "$BACKUP_COMMAND"

# http://stackoverflow.com/questions/90418/exit-shell-script-based-on-process-exit-code
rc=$? 
if [[ $rc != 0 ]]; then 
  log "BACKUP COMMAND EXITED WITH RETURN CODE $rc. ABORTING"
  log "REMOVING $DUMP_FILE_NAME"
  rm -f "$DUMP_FILE_NAME"
  exit $rc; 
fi

# rotation
BACKUP_TYPE="H"
log "REMOVING OLD HOURLY BACKUPS"
remove_old_entries "$NOW" "H"

if [[ "$HOUR" -eq "$DAILY_HOUR" ]]; then
  BACKUP_TYPE="D"
  log "REMOVING OLD DAILY BACKUPS"
  remove_old_entries "$NOW" "D"

  if [[ "$DOW" -eq "$WEEKLY_DAY" ]]; then
    BACKUP_TYPE="W"
    log "REMOVING OLD WEEKLY BACKUPS"
    remove_old_entries "$NOW" "W"
  fi

  if [[ "$DAY" -eq "$MONTHLY_DATE" ]]; then
    BACKUP_TYPE="M"
  fi
fi

# upload dump
BACKUP_KEY=$KEY_PREFIX\_$BACKUP_TYPE\_$NOW
BACKUP_AWS_PATH=$(s3_key_path $BACKUP_KEY)

log "COPYING TO S3 @ $BACKUP_AWS_PATH"
aws s3 cp $DUMP_FILE_NAME $BACKUP_AWS_PATH
log "REMOVING $DUMP_FILE_NAME"
rm "$DUMP_FILE_NAME"

