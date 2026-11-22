#!/bin/bash

for f in /home/malzi/*; do
	echo "$(du -sh "$f")"
done
