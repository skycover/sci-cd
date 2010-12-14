#!/bin/sh
# args are <file> <pattern> <string-to-replace>
#set -x
awk -v repl="$3" '//{s=1}/'"$2"'/{print repl;s=0;r=1}//{if(s)print}END{if(!r)print repl}' "$1" >"$1.tmp"
if [ $? -eq 0 ]; then
 mv "$1" "$1.bkp"
 mv "$1.tmp" "$1"
else
 exit 1
fi
