#!/bin/bash

# Author  : Peter Lagoni Kirkemann
# Purpose : 

showhelp(){
  echo "`basename "$0"` record.file"
}

TIME="$(date +%a\ %H:%M:%S)"



#Sun 21:21:16 | 1 | Kitchen | Hue White E27 | ON | YES | 100 | ---

#awk -F '|' {'print "./hue.sh "$2" " $5 " "$7'} record.file
#./hue.sh  1   ON   100 
#./hue.sh  2   ON   89 
#./hue.sh  3   ON   100 
#./hue.sh  4   ON   100 
#./hue.sh  5   OFF   --- 
#./hue.sh  6   ON   4 
#./hue.sh  7   ON   4 
#./hue.sh  1   OFF   --
