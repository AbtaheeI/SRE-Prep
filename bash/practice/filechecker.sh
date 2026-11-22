#!/bin/bash

file=$1

if [[ -f "$file" ]]; then
	echo "is a file"
elif [[ -d "$file" ]]; then
	echo "is a directory"
else
	echo "doesn't exist"
fi
