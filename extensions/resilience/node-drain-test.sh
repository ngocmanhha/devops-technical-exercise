#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-greeter-prod}"
NODE="${NODE:-k3d-what3words-exercise-agent-0}"

EVIDENCE_DIR="extensions/resilience/evidence/node-drain"
LOAD_LOG="${EVIDENCE_DIR}/requests.csv"

mkdir -p "${EVIDENCE_DIR}"

echo "==> Capturing initial pod placement"

kubectl get pods \
  -n "${NAMESPACE}" \
  -o wide \
  > "${EVIDENCE_DIR}/pods-before.txt"

kubectl get pdb \
  -n "${NAMESPACE}" \
  > "${EVIDENCE_DIR}/pdb-before.txt"

echo "==> Starting continuous traffic"

OUTPUT="${LOAD_LOG}" \
  extensions/resilience/load-test.sh \
  > /dev/null &

LOAD_PID=$!

cleanup() {
  kill "${LOAD_PID}" 2>/dev/null || true
}

trap cleanup EXIT

sleep 5

echo "==> Draining ${NODE}"

kubectl drain "${NODE}" \
  --ignore-daemonsets \
  --delete-emptydir-data \
  | tee "${EVIDENCE_DIR}/drain.txt"

echo "==> Waiting for deployment availability"

kubectl rollout status \
  deployment/greeter-greeter \
  -n "${NAMESPACE}" \
  --timeout=120s \
  | tee "${EVIDENCE_DIR}/rollout-status.txt"

kubectl get pods \
  -n "${NAMESPACE}" \
  -o wide \
  > "${EVIDENCE_DIR}/pods-after-drain.txt"

sleep 10

echo "==> Restoring worker"

kubectl uncordon "${NODE}" \
  | tee "${EVIDENCE_DIR}/uncordon.txt"

sleep 5

cleanup
trap - EXIT

echo "==> Calculating results"

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

  if (total > 0)
    printf "Success rate:    %.2f%%\n", (success / total) * 100

  if (total > 0)
    printf "Average latency: %.4fs\n", latency / total

  printf "Max latency:     %.4fs\n", max
}
' "${LOAD_LOG}" \
  | tee "${EVIDENCE_DIR}/summary.txt"
