#!/usr/bin/env bash

set -euo pipefail

URL="${URL:-http://localhost:8080}"
HOST="${HOST:-prod.greeter.local}"
INTERVAL="${INTERVAL:-0.1}"
OUTPUT="${OUTPUT:-/tmp/greeter-load-test.csv}"
SUMMARY_OUTPUT="${SUMMARY_OUTPUT:-${OUTPUT%.csv}-summary.txt}"

mkdir -p "$(dirname "${OUTPUT}")"

echo "timestamp,http_code,time_total,result" > "${OUTPUT}"

summarize() {
  echo
  echo "==> Load test summary"

  awk -F',' '
  NR > 1 {
    total++

    if ($4 == "success")
      success++
    else
      failure++

    latency += $3

    if ($3 > max)
      max = $3
  }

  END {
    printf "Requests:        %d\n", total
    printf "Successful:      %d\n", success
    printf "Failed:          %d\n", failure

    if (total > 0) {
      printf "Success rate:    %.2f%%\n", (success / total) * 100
      printf "Average latency: %.4fs\n", latency / total
      printf "Max latency:     %.4fs\n", max
    }
  }
  ' "${OUTPUT}" | tee "${SUMMARY_OUTPUT}"
}

cleanup() {
  summarize
}

trap cleanup EXIT INT TERM

echo "==> Starting load test"
echo "URL:      ${URL}"
echo "Host:     ${HOST}"
echo "Interval: ${INTERVAL}s"
echo "Output:   ${OUTPUT}"
echo

while true; do
  TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")"

  CURL_OUTPUT="$(
    curl \
      --silent \
      --show-error \
      --output /dev/null \
      --write-out '%{http_code},%{time_total}' \
      --header "Host: ${HOST}" \
      --max-time 10 \
      "${URL}/" \
      2>/dev/null || true
  )"

  if [[ -z "${CURL_OUTPUT}" ]]; then
    HTTP_CODE="000"
    TIME_TOTAL="0"
  else
    HTTP_CODE="${CURL_OUTPUT%%,*}"
    TIME_TOTAL="${CURL_OUTPUT#*,}"
  fi

  if [[ "${HTTP_CODE}" =~ ^2[0-9][0-9]$ ]]; then
    STATUS="success"
  else
    STATUS="failure"
  fi

  echo "${TIMESTAMP},${HTTP_CODE},${TIME_TOTAL},${STATUS}" \
    | tee -a "${OUTPUT}"

  sleep "${INTERVAL}"
done
