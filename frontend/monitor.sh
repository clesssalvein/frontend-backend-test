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

# when alarm about status triggered, here you can see whether alarm was triggered or not
monitorBackendAlarmAcceptedDir="${monitorBaseDir}/backendAlarmAccepted"

# telegram bot's info to send notifications
telegramBotId="bot460040471:AAG0t1SitML7WAcFmPYedB2pZbY14CQEYCY"
telegramChatId="250607873"


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

  # backend name
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

  # getting backend listen port status
  backendAppPortStatus=$(nmap ${backendAppHost} -p${backendAppPort} \
    | awk -v backendAppPort="${backendAppPort}" '$0~backendAppPort {print $0}' \
    | awk '/open/ {print $2}')

  # debug
  echo ${backendAppPortStatus}

  # dynamic vars
  backendStatusFile="${monitorBackendStatusDir}/${backendDomainName}/backendStatus.txt"
  backendAlarmAcceptedFile="${monitorBackendAlarmAcceptedDir}/${backendDomainName}/backendAlarmAccepted.txt"
  backendLogFile="${monitorBackendLogDir}/${backendDomainName}/backendLog.txt"

  # create necessary files
  if ! test -f ${backendStatusFile}; then
    touch ${backendStatusFile}
  fi

  if ! test -f ${backendAlarmAcceptedFile}; then
    touch ${backendAlarmAcceptedFile}
  fi

  if ! test -f ${backendLogFile}; then
    touch ${backendLogFile}
  fi

  # if backend service port is open
  if [ "${backendAppPortStatus}" == "open" ]; then
    if [ "$(cat ${backendStatusFile})" != "1" ]; then
      # backend status ON
      echo "1" > ${backendStatusFile}

      # debug
      echo "Backend \"${backendDomainName}\" on port \"${backendAppPort}\" became OK!";

      # backend log write
      echo "${dateTime} Backend \"${backendDomainName}\" on port \"${backendAppPort}\" became OK!" >> ${backendLogFile}

      # telegram notify
      curl --request POST https://api.telegram.org/${telegramBotId}/sendMessage?chat_id=${telegramChatId} \
        --data "text=${dateTime} Backend \"${backendDomainName}\" on port \"${backendAppPort}\" became OK!"
    fi

    if [ "$(cat ${backendAlarmAcceptedFile})" != "0" ]; then
      # backend alarmAccepted OFF
      echo "0" > ${backendAlarmAcceptedFile}
    fi
  fi

  # if backend service port is closed
  if [ "${backendAppPortStatus}" != "open" ]; then
    # if alarm is NOT accepted
    if [ "$(cat ${backendAlarmAcceptedFile})" != "1" ]; then
      # debug
      echo "Alarm! Backend \"${backendDomainName}\" on port \"${backendAppPort}\" Failed!";

      # backend status ON
      echo "0" > ${backendStatusFile}

      # backend alarmAccepted ON
      echo "1" > ${backendAlarmAcceptedFile}

      # backend log write
      echo "${dateTime} Alarm! Backend \"${backendDomainName}\" on port \"${backendAppPort}\" Failed!" >> ${backendLogFile}

      # telegram notify
      curl --request POST https://api.telegram.org/${telegramBotId}/sendMessage?chat_id=${telegramChatId} \
        --data "text=${dateTime} Alarm! Backend \"${backendDomainName}\" on port \"${backendAppPort}\" Failed!"
    fi
  fi
done

# makeup
echo "";
echo "---";
echo "";

# pause beetween iterations
sleep 3;

# infinite loop iteration end
done
