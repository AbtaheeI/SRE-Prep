#!/bin/bash

set -euo pipefail

[[ "$#" -gt 0 ]] || { echo "no arguments" >&2; exit 1;}
