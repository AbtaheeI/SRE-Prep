#!/bin/bash

name=$1

if [ -z "$name" ]; then
	echo "Usage: $0 NAME"
	exit 1
else
	echo "Hi $name"
fi
