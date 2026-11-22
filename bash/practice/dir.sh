#!/bin/bash

is_dir() {
	local name="$1"
	if [[ -d "$name" ]]; then
		return  0
	else
		return  1
	fi
}

if is_dir "/home/malzi"; then
	echo "yes";
else
	echo "no";
fi
