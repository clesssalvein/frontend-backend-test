#!/bin/bash

#####
#
# Backup
# by @ClessAlvein
#
#####


# VARS

# base local dir to store backups
backupBaseDir="/var/backup"

# current date and time
dateTimeCurrent=`date +%Y-%m-%d_%H-%M-%S`

# quantity of the last newest daily backups,
# which you want to leave after removing old backups
leaveNewestDailyBackupsNumber="7"

# dirs to backup
# it's necessary to use full paths of the directories and ";" as delimiter
backupDirsList="/opt;/etc/nginx;/etc/systemd"


# SCRIPT START

# backuping each dir in the list
IFS=';'
for dirWithPath in ${backupDirsList}
do
  # debug
  echo "${dirWithPath}"

  # getting pseudo-path for backup dirs, put "_" instead of "/"
  dirWithPseudoPath=`echo ${dirWithPath} | sed -e 's:\/:\_:g'`

  # getting dir name without a path
  dirName=${dirWithPath##*/}

  # debug
  echo ${dirName}

  # creating necessary dirs
  if ! [ -d ${backupBaseDir}/${dirWithPseudoPath}/daily ]; then
    mkdir -p ${backupBaseDir}/${dirWithPseudoPath}/daily
  fi

  # arch a dir
  tar -pczvf ${backupBaseDir}/${dirWithPseudoPath}/daily/${dirName}_${dateTimeCurrent}.tgz ${dirWithPath}

  # getting error code of the daily archiving
  backupDailySuccess=$?

  # if daily backup is OK
  if [ ${backupDailySuccess} -eq 0 ]; then
    # if backup dir is exist
    if [ -d ${backupBaseDir}/${dirWithPseudoPath}/daily/ ]; then
      # removing old backups, leaving only newest last backups (check the var "leaveNewestDailyBackupsNumber")
      cd ${backupBaseDir}/${dirWithPseudoPath}/daily/
      ls -lt \
        | sed /^total/d \
        | awk -v leaveNewestDailyBackupsNumber=${leaveNewestDailyBackupsNumber} 'FNR>leaveNewestDailyBackupsNumber {print $9}' \
        | xargs rm -rf {};
    fi
  fi

  # monthly backup - every 1st day of the month
  if [ "`date +%d`" -eq "01" ]; then
    # creating necessary dir
    if ! [ -d ${backupBaseDir}/${dirWithPseudoPath}/monthly ]; then
        mkdir -p ${backupBaseDir}/${dirWithPseudoPath}/monthly
    fi

    # arch a dir
    tar -pczvf ${backupBaseDir}/${dirWithPseudoPath}/monthly/${dirName}_${dateTimeCurrent}.tgz ${dirWithPath}
  fi
done
