Philips Hue Bash
****
Author  : Peter Lagoni Kirkemann
Purpose : Control Philips HUE lights from a shell on Linux

Inspired by https://github.com/danradom/hue

Configuration
****
You need to fill in values in hue.config please see inside this file for further comments.

Examples
****
See status for all lights
/hue.sh all status

turn of lights in group "kitchen"
./hue.sh kitchen off

adjust lights in group "livingroom" to "40%" brightness
./hue.sh livingroom on 40

turn all lights off
./hue.sh all off
