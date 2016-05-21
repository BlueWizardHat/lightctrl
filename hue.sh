#!/bin/bash

# Author  : Peter Lagoni Kirkemann
# Purpose : Control Philips HUE lights from a shell

# Inspired by https://github.com/danradom/hue

# include configuration file
source ./hue.config

showhelp(){
  echo "`basename "$0"` <group|bulb|funtion> <on|off|status> <brightness>"
  echo ""
  echo "Examples:"
  echo "`basename "$0"` 5 on 100"
  echo "`basename "$0"` livingroom on 80"
  echo "`basename "$0"` livingroom off"
  echo "`basename "$0"` status all"
  echo "`basename "$0"` record"
}

# This can be a direct number of a bulb or a predefined group
REGEXNUMBER='^[0-9]+$'
if ! [[ $1 =~ ${REGEXNUMBER} ]] ; then
  # So if it's not a number, it should be a group
  # convert group to uppercase
  GROUP="$(echo $1 | tr '[:lower:]' '[:upper:]')"
  if [ "$GROUP" = "LIVINGROOM" ]; then
    LIGHTS="$LIVINGROOM"
  elif [ "$GROUP" = "KITCHEN" ]; then
    LIGHTS="$KITCHEN"
  elif [ "$GROUP" = "FRONTDOOR" ]; then
    LIGHTS="$FRONTDOOR"
  elif [ "$GROUP" = "ALL" ]; then
    LIGHTS="$ALL"
  elif [ "$GROUP" = "BATHROOMUPSTAIRS" ]; then
    LIGHTS="$UPSTAIRS"
  else
    echo "Unknown group"
    showhelp
  fi
else
  # the number should be a direct reference to a bulb
  LIGHTS="$1"
fi

STATE=$2
BRIGHTNESS=$3
STARTTIME="$(date +%a\ %H:%M:%S)"

# All this can be combined
# will get status true|false for a bulb to see if the bridge believes it to be on or off
check_if_on(){
  echo "$(curl -X GET -s "http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}" |cut -d, -f1 |cut -d\{ -f3 |cut -d: -f2)"
}

type_of_bulb(){
  echo "$(curl -X GET -s "http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}" | egrep -o '\"modelid\": \"[^"]+' | awk -F '"' {'print $NF}')"
}

check_if_reachable(){
  echo "$(curl -X GET -s "http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}" | egrep -o '\"reachable\":[^ ]+' | awk -F '"' {'print $NF}' | tr -d ':},')"
}

name_of_light(){
  echo "$(curl -X GET -s "http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}" | egrep -o '\"name\": \"[^"]+' | awk -F '"' {'print $NF}')"
}

# Return brightness as a percentage
brightness_of_light(){
  ABSOLUTE="$(curl -X GET -s "http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}" |cut -d, -f2 |cut -d: -f2)"
  RELATIVE="$((${ABSOLUTE}*100/254))"
  echo "${RELATIVE}"
}

hue_of_light(){
  echo "$(curl -X GET -s "http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}" |cut -d, -f3 |cut -d: -f2 |tr -d '}')"
}

# light off function
light_off()
{
  for LIGHT in ${LIGHTS}; do
    ON="$(check_if_on)"
    while [ $ON = "true" ]; do
      curl -X PUT -d '{"on":false}' http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}/state > /dev/null 2>&1
      ON="$(check_if_on)"
      sleep 0.1 # not sure a delay is needed
    done
  done
}

# light on function
light_on()
{
  # determine brightness
  BRIGHT=$((${BRIGHTNESS}*254/100))

  for LIGHT in ${LIGHTS}; do
    TYPE="$(type_of_bulb)"

    # HUE White
    if [ $(echo ${TYPE} |grep -c LWB006) = 1 ]; then
      #TYPE="White E27"
      ON="$(check_if_on)"
      if [ $ON = "true" ]; then
        curl -X PUT -d '{"bri":'${BRIGHT}'}' http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}/state > /dev/null 2>&1
      elif [ $ON = "false" ]; then
        curl -X PUT -d '{"on":true,"bri":'${BRIGHT}'}' http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}/state > /dev/null 2>&1
      fi
    elif [ $(echo ${TYPE} |grep -c "PAR16 50 TW")  = 1 ]; then
      #TYPE="Lightify GU10"
      ON="$(check_if_on)"
      if [ $ON = "true" ]; then
        curl -X PUT -d '{"bri":'${BRIGHT}'}' http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}/state > /dev/null 2>&1
      elif [ $ON = "false" ]; then
        curl -X PUT -d '{"on":true,"bri":'${BRIGHT}'}' http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}/state > /dev/null 2>&1
      fi
    else
      echo "Type of bulb is unknown"
    fi
  done
}

# light status function
light_status(){
  echo "#  | Name                   | Type       | State | Reachable | Brightness | Hue"
  echo "-------------------------------------------------------------------------------"

  for LIGHT in ${LIGHTS}; do
    unset NAME TYPE STATE REACH BRIGHTNESS HUE
    TYPE="$(type_of_bulb)"
    if [ $(echo ${TYPE} |grep -c LWB006) = 1 ]; then
      TYPE="Hue White E27"
    elif [ $(echo ${TYPE} |grep -c "PAR16 50 TW")  = 1 ]; then
      TYPE="Lightify GU10"
    else
      echo "Type of light is unknown"
      exit 1
    fi

    ON="$(check_if_on)"
    NAME="$(name_of_light)"
    REACHABLE="$(check_if_reachable)"
    if [ $REACHABLE == "true" ]; then
      if [ $ON == "true" ]; then
        BRIGHTNESS="$(brightness_of_light)"
	  STATE="ON"
      else
        BRIGHTNESS="---"
	  STATE="OFF"
      fi
	REACH="YES"
    else
      BRIGHTNESS="?"
	ON="?"
	STATE="?"
	REACH="NO"
    fi
    HUE="---"

    printf "%-2s | %-22s | %-10s | %-5s | %-9s | %-10s | %-10s\n" "${LIGHT}" "${NAME}" "${TYPE}" "${STATE}" "${REACH}" "${BRIGHTNESS}" "${HUE}"
  done
}

# light status record
light_status_record(){
  TIME="$(date +%a\ %H:%M:%S)"
  STATUSFILE="record.test"
  echo "$(date +%a\ %H:%M:%S) : Recording light status to file since ${STARTTIME} [Ctrl + c to break]"

  for LIGHT in ${LIGHTS}; do
    unset NAME TYPE STATE REACH BRIGHTNESS HUE
    TYPE="$(type_of_bulb)"
    if [ $(echo ${TYPE} |grep -c LWB006) = 1 ]; then
      TYPE="White E27"
      ON="$(check_if_on)"
      NAME="$(name_of_light)"
      REACHABLE="$(check_if_reachable)"
      if [ $REACHABLE == "true" ]; then
        if [ $ON == "true" ]; then
          BRIGHTNESS="$(brightness_of_light)"
	  STATE="ON"
        else
          BRIGHTNESS="---"
	  STATE="OFF"
        fi
	REACH="YES"
      else
        BRIGHTNESS="?"
	ON="?"
	STATE="?"
	REACH="NO"
      fi
      HUE="---"
    else
      echo "Type of light is unknown"
      exit 1
    fi

    # get the last recorded status for a light
    LASTSTATE="$(egrep "^[[:alpha:]]{3} [[:digit:]:]{8} \| ${LIGHT}" "${STATUSFILE}" | tail -n 1)"
    # so is there a former state
    if [ -z "${LASTSTATE}" ]; then
      echo "First entry for light ${LIGHT} (${NAME}) in file ${STATUSFILE} @ ${TIME}"
      echo "${TIME} | ${LIGHT} | ${NAME} | ${TYPE} | ${STATE} | ${REACH} | ${BRIGHTNESS} | ${HUE}" >> "${STATUSFILE}"
    else
      echo "${LASTSTATE}" | tail -n 1 | awk -F '|' {'print $5 " " $7 " " $8'} |
        while read LSTATE LBRIGHTNESS LHUE; do
  	  # something changed, time for an update
          if [ "${LSTATE}" != "${STATE}" ] || [ "${LBRIGHTNESS}" != "${BRIGHTNESS}" ] || [ "${LHUE}" != "${HUE}" ]; then
            echo "Adding entry for light ${LIGHT} (${NAME}) in file ${STATUSFILE} @ ${TIME}"
            echo "${TIME} | ${LIGHT} | ${NAME} | ${TYPE} | ${STATE} | ${REACH} | ${BRIGHTNESS} | ${HUE}" >> "${STATUSFILE}"
  	  fi
        done
    fi

  done
  sleep 10
  light_status_record
}

# perform action
if [ "$2" = "on" ]; then
        light_on
elif [ "$2" = "off" ]; then
        light_off
elif [ "$2" = "status" ]; then
        light_status
elif [ "$2" = "record" ]; then
        light_status_record
fi
