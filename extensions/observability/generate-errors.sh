#!/usr/bin/env bash

set -euo pipefail

URL="${URL:-http://localhost:8080}"
HOST="${HOST:-prod.greeter.local}"

while true; do
  curl \
    --silent \
    --output /dev/null \
    --header "Host: ${HOST}" \
    "${URL}/boom" || true

  sleep 0.1
done
