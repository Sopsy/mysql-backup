#!/bin/bash
# Shell script to backup MySQL databases
# Version: 2.1
# Author: Aleksi "Sopsy" Kinnunen
# URL: https://github.com/Sopsy/mysql-backup
# License: MIT
#
# For user, see: http://dev.mysql.com/doc/refman/5.6/en/mysql-config-editor.html
# E.g.: mysql_config_editor set --login-path=client --host=localhost --user=backup --password
# Needed permissions: SELECT, LOCK TABLES, SHOW VIEW, PROCESS, TRIGGER, EVENT
#

## CONFIG ##

# Days to save old backups (date -d, 0 to disable limit)
DAYSTOSAVE=30

# How many versions to keep (0 to disable limit)
NUMTOSAVE=0

# Compression method ('none', 'gzip' and 'zstd' supported)
COMPRESS_METHOD='zstd'

# Compression level (1-9 for GZIP, 1-19 for ZSTD)
GZIP_LEVEL='1'
ZSTD_LEVEL='5'

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
ZSTD="$(which zstd)"
RM="$(which rm)"

## END CONFIG ##

if [ ! -d ${DEST} ]; then
  mkdir -p ${DEST}
fi

# Get all databases as a list first
DBS="$(${MYSQL} -Bse 'show databases')"

echo "Backup destination is ${DEST}"

if [ ${COMPRESS_METHOD} = 'none' ]; then
  FILE_EXT='sql'
  function compress() {
    cat
  }
elif [ ${COMPRESS_METHOD} = 'gzip' ]; then
  FILE_EXT='sql.gz'
  function compress() {
    ${GZIP} -${GZIP_LEVEL}
  }
elif [ ${COMPRESS_METHOD} = 'zstd' ]; then
  FILE_EXT='sql.zst'
  function compress() {
    ${ZSTD} -${ZSTD_LEVEL} --threads=0 --long
  }
else
  echo "Unsupported compression method '${COMPRESS_METHOD}', check config"
  exit 1
fi

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
    FILE="${DEST}/$(hostname).${DB}.$(date +"%F_%H-%M-%S").${FILE_EXT}"
    if [ -f ${FILE} ]; then
      rm ${FILE}
      echo "Duplicate file removed: ${FILE}"
    fi
    echo "Backing up ${DB}..."
    ${MYSQLDUMP} --hex-blob --single-transaction --routines --triggers --events ${DB} | compress > ${FILE}
    ${CHMOD} 0600 ${FILE}
    if [ ${NUMTOSAVE} != 0 ]; then
      echo "Removing all except the ${NUMTOSAVE} newest backup(s) for ${DB}..."
      ls -t ${DEST}/$(hostname).${DB}.*.${FILE_EXT} | tail -n +`expr ${NUMTOSAVE} + 1` | xargs -r rm --
    fi
  else
    echo "Skipping ${DB}"
  fi
done

# Remove old backups
if [ ${DAYSTOSAVE} != 0 ]; then
  echo "Removing old MySQL backups..."
  find ${DEST}/$(hostname).*.${FILE_EXT} -mtime +${DAYSTOSAVE} -type f -delete -print
fi

# Remove permissions from all other users except the one running this script
${CHOWN} ${USER}:${USER} -R ${DEST}
${CHMOD} 0700 ${DEST}
