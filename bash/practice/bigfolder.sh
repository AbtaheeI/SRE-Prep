#!/bin/bash

folder=$1
if [ -z "$folder" ]; then
	echo "no folder chosen"
	exit 1
fi

size=$(du -sm "$folder" | cut -f1)

if [ "$size" -lt 11 ]; then
	msg="OK: $folder is $size MB"
else
	msg="WARNING: $folder is $size MB"
fi
echo "$msg"
logger -t bigfolder "$msg"

