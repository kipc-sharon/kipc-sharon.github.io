#!/usr/bin/env bash
# Usage: ./tools/gen-lock-hash.sh "yourpassword"
# Outputs the SHA-256 hash to paste into front matter as lockPasswordHash
if [ -z "$1" ]; then
  echo "Usage: $0 <password>"
  exit 1
fi
echo -n "$1" | sha256sum | awk '{print $1}'
