#!/bin/bash
# Shell script to backup MySQL databases
# Version: 1.11
# Author: Aleksi "Sopsy" Kinnunen
# URL: https://github.com/Sopsy/mysql-backup
# License: MIT
#
# For user, see: http://dev.mysql.com/doc/refman/5.6/en/mysql-config-editor.html
# E.g.: mysql_config_editor set --login-path=client --host=localhost --user=backup --password
# Needed permissions: SELECT, LOCK TABLES, SHOW VIEW, PROCESS, TRIGGER, EVENT
#

## CONFIG ##

# Days to save old backups (date -d)
DAYSTOSAVE=30

# Backup destination directory
DEST="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )/mysql-backups"

# SKIP BACKUP for these databases
SKIP=( "test" "phpmyadmin" "mysql" "information_schema" "performance_schema" "sys" )

# Linux bin paths, should be autodetected
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"
CHOWN="$(which chown)"
CHMOD="$(which chmod)"
GZIP="$(which gzip)"
RM="$(which rm)"

## END CONFIG ##

if [ ! -d ${DEST} ]; then
  mkdir -p ${DEST}
fi

# Get all databases as a list first
DBS="$(${MYSQL} -Bse 'show databases')"

echo "Backup destination is ${DEST}"

for DB in ${DBS}
do
  SKIPDB=0
  if [ "${SKIP}" != "" ]; then
    for I in "${SKIP[@]}"
    do
      if [ "${DB}" == "${I}" ]; then
        SKIPDB=1
      fi
    done
  fi

  if [ ${SKIPDB} == 0 ]; then
    # Do backup
    FILE="${DEST}/$(hostname).${DB}.$(date +"%F_%H-%M-%S").sql.gz"
    if [ -f ${FILE} ]; then
      rm ${FILE}
      echo "Duplicate file removed: ${FILE}"
    fi
    echo "Backing up ${DB}..."
    ${MYSQLDUMP} --hex-blob --single-transaction --routines --triggers --events ${DB} | ${GZIP} -1 > ${FILE}
    ${CHMOD} 0600 ${FILE}
  else
    echo "Skipping ${DB}"
  fi
done

# Remove old backups
echo "Removing old MySQL backups..."
find ${DEST}/$(hostname).*.gz -mtime +${DAYSTOSAVE} -type f -delete -print

# Remove permissions from all other users except the one running this script
${CHOWN} ${USER}:${USER} -R ${DEST}
${CHMOD} 0700 ${DEST}
