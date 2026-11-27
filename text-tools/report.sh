#!/bin/bash

set -euo pipefail

if [[ "$#" -eq 0 ]]; then
	echo "No argument given" >&2
	exit 1
fi


log_file="$1"

if [[ ! -f "$log_file" ]]; then
	echo "File not found" >&2
	exit 1
fi

output=$(cat "$log_file" | cut -d " " -f 9 | sort | uniq -c | sort -rn | head)
output2=$(cat "$log_file" | cut -d " " -f 1 | sort | uniq -c | sort -rn | head -n 5)

echo "== Status codes =="
echo "$output"
echo "== IP Addresses =="
echo "$output2"

# output=$(cat "$log_file" | awk '{count[$9]++} END {for (m in count) print count[m], m}' | sort -nr | head)
# output2=$(cat "$log_file" | awk '{count[$1]++} END {for (n in count) print count[n], n}' | sort -nr | head -n 5)
