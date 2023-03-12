#!/bin/bash

#####
#
# Backend services monitoring
# by @ClessAlvein
#
#####


# VARS

# host with running backends
backendAppHost="127.0.0.1"

# dir with nginx backend configs
nginxBackendConfigsDirPath="/etc/nginx/backend.d"

# base dir for monitor script
monitorBaseDir="/opt/monitor"

# dir for backends' logs
monitorBackendLogDir="${monitorBaseDir}/backendLog"

# dir for backends' actual status
monitorBackendStatusDir="${monitorBaseDir}/backendStatus"

# when alarm status is triggered, here you can see whether alarm was triggered or not
monitorBackendAlarmAcceptedDir="${monitorBaseDir}/backendAlarmAccepted"

# telegram bot's info to send the notifications
telegramBotId="bot4***1:A***Y"
telegramChatId="2***3"


# SCRIPT START

# infinite loop start
while true;
do

# current dateTime
dateTime=`date +%Y-%d-%m_%H-%M-%S`

# array with nginx backend config file names
arrayNginxBackendConfigs=()
while IFS= read -r line || [[ "$line" ]];
  do
    arrayNginxBackendConfigs+=( "$line" )
  done < <( ls ${nginxBackendConfigsDirPath}/ | xargs -n 1 basename )

# for each nginx backend config file
for nginxBackendConfig in "${arrayNginxBackendConfigs[@]}";
do
  # debug
  echo "${nginxBackendConfig}";

  # getting backend name (domain name of the service) from the nginx backend config
  backendDomainName=$(cat "${nginxBackendConfigsDirPath}/${nginxBackendConfig}" \
    | awk '/server_name/ {print $2}' \
    | sed 's/;//');

  # debug
  echo ${backendDomainName}

  # getting backend app port from the nginx backend config
  backendAppPort=$(cat "${nginxBackendConfigsDirPath}/${nginxBackendConfig}" \
    | awk '/proxy_pass/ {print $2}' \
    | awk -F":" '{print $3}' \
    | sed 's/;//');

  # debug
  echo "${backendAppPort}";

  # creating necessary dirs
  if ! [ -d ${monitorBackendStatusDir}/${backendDomainName}/ ]; then
    mkdir -p ${monitorBackendStatusDir}/${backendDomainName}
  fi

  if ! [ -d ${monitorBackendAlarmAcceptedDir}/${backendDomainName}/ ]; then
    mkdir -p ${monitorBackendAlarmAcceptedDir}/${backendDomainName}
  fi

  if ! [ -d ${monitorBackendLogDir}/${backendDomainName}/ ]; then
    mkdir -p ${monitorBackendLogDir}/${backendDomainName}
  fi

  # getting backend service's listened port status
  backendAppPortStatus=$(nmap ${backendAppHost} -p${backendAppPort} \
    | awk -v backendAppPort="${backendAppPort}" '$0~backendAppPort {print $0}' \
    | awk '/open/ {print $2}')

  # debug
  echo ${backendAppPortStatus}

  # dynamic vars
  backendStatusFile="${monitorBackendStatusDir}/${backendDomainName}/backendStatus.txt"
  backendAlarmAcceptedFile="${monitorBackendAlarmAcceptedDir}/${backendDomainName}/backendAlarmAccepted.txt"
  backendLogFile="${monitorBackendLogDir}/${backendDomainName}/backendLog.txt"

  # create empty necessary files (in case they don't exist)
  if ! test -f ${backendStatusFile}; then
    touch ${backendStatusFile}
  fi

  if ! test -f ${backendAlarmAcceptedFile}; then
    touch ${backendAlarmAcceptedFile}
  fi

  if ! test -f ${backendLogFile}; then
    touch ${backendLogFile}
  fi

  # if backend service's port is open
  if [ "${backendAppPortStatus}" == "open" ]; then
    if [ "$(cat ${backendStatusFile})" != "1" ]; then
      # write backend status ON
      echo "1" > ${backendStatusFile}

      # debug
      echo "Backend \"${backendDomainName}\" on port \"${backendAppPort}\" became OK!";

      # backend log write
      echo "${dateTime} Backend \"${backendDomainName}\" on port \"${backendAppPort}\" became OK!" >> ${backendLogFile}

      # sending telegram notify
      curl --request POST https://api.telegram.org/${telegramBotId}/sendMessage?chat_id=${telegramChatId} \
        --data "text=${dateTime} Backend \"${backendDomainName}\" on port \"${backendAppPort}\" became OK!"
    fi

    # if alarmAccepted status is ON or empty
    if [ "$(cat ${backendAlarmAcceptedFile})" != "0" ]; then
      # write backend alarmAccepted OFF
      echo "0" > ${backendAlarmAcceptedFile}
    fi
  fi

  # if backend service's port is closed
  if [ "${backendAppPortStatus}" != "open" ]; then
    # if alarm is NOT accepted
    if [ "$(cat ${backendAlarmAcceptedFile})" != "1" ]; then
      # debug
      echo "Alarm! Backend \"${backendDomainName}\" on port \"${backendAppPort}\" Failed!";

      # write backend status ON
      echo "0" > ${backendStatusFile}

      # write backend alarmAccepted ON
      echo "1" > ${backendAlarmAcceptedFile}

      # backend log write
      echo "${dateTime} Alarm! Backend \"${backendDomainName}\" on port \"${backendAppPort}\" Failed!" >> ${backendLogFile}

      # sending telegram notify
      curl --request POST https://api.telegram.org/${telegramBotId}/sendMessage?chat_id=${telegramChatId} \
        --data "text=${dateTime} Alarm! Backend \"${backendDomainName}\" on port \"${backendAppPort}\" Failed!"
    fi
  fi
done

# console output makeup
echo "";
echo "---";
echo "";

# pause beetween iterations
sleep 3;

# infinite loop iteration end
done
