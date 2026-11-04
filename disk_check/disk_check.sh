#!/bin/bash

count=0
while read percent disk; do
 	if [ $(echo "$percent" | tr -d "%") -gt 80 ]; then
		msg="WARNING: $disk is $percent full"
		echo "$msg"
		logger -t disk_check "$msg"
		count=$((count + 1))
	fi
done < <(df --output=pcent,target | tail -n +2)

if [ "$count" -eq 0 ]; then
	goodmsg="OK: all disks under 80%"
	echo "$goodmsg"
	logger -t disk_check "$goodmsg"
else
	exit 1
fi


