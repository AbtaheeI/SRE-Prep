#!/bin/bash

set -euo pipefail

[[ "$#" -gt 0 ]] || { echo "No argument given" >&2; exit 1; }

dir="$1"
[[ -d "$dir" ]] || { echo "argument is not a directory" >&2; exit 1; }

tar -czf "/var/backups/$(basename "$dir")-$(date +%F_%H%M%S).tar.gz" "$1"

cleanup() {
	ls -t "/var/backups/$(basename "$dir")"-*.tar.gz | tail -n +6 | while read -r line; do
		rm -- "$line"
	done
}

cleanup
