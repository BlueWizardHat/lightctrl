#!/bin/bash

# Author  : Peter Lagoni Kirkemann
# Purpose : Control Philips HUE lights from a shell

# Inspired by https://github.com/danradom/hue

# include configuration file
source ./hue.config

# convert group to uppercase
GROUP="$(echo $1 | tr '[:lower:]' '[:upper:]')"
STATE=$2
BRIGHTNESS=$3

#declare -A lights=([livingrom]="1 2 3 4 5"  [kitchen]="6 7 8 9")
#roomlights=${lights["livingroom"]}

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
fi

# All this can be combined
# will get status true|false for a bulb to see if the bridge believes it to be on or off
check_if_on(){
  echo "$(curl -X GET -s "http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}" |cut -d, -f1 |cut -d\{ -f3 |cut -d: -f2)"
}

type_of_bulb(){
  echo "$(curl -X GET -s "http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}" |sed -e 's/.*\"modelid/modelid/' -e 's/\,.*//' -e 's/type\": \"//' -e 's/\"//')"
}

check_if_reachable(){
  echo "$(curl -X GET -s "http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}" |cut -d, -f4 |cut -d: -f2 |tr -d '}')"
}

name_of_light(){
  echo "$(curl -X GET -s "http://${BRIDGE}/api/${USERNAME}/lights/${LIGHT}" |cut -d, -f6 |cut -d: -f2 |sed -e 's/}//' -e 's/"//' -e 's/\"//')"
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
      TYPE="White E27"
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

    printf "%-2s | %-22s | %-10s | %-5s | %-9s | %-10s | %-10s\n" "${LIGHT}" "${NAME}" "${TYPE}" "${STATE}" "${REACH}" "${BRIGHTNESS}" "${HUE}"
  done
}

# perform action
if [ "$2" = "on" ]; then
        light_on
elif [ "$2" = "off" ]; then
        light_off
elif [ "$2" = "status" ]; then
        light_status
fi
