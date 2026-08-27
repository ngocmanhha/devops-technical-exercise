#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-greeter-prod}"

EVIDENCE_DIR="extensions/resilience/evidence/rolling-update"
LOAD_LOG="${EVIDENCE_DIR}/requests.csv"

mkdir -p "${EVIDENCE_DIR}"

kubectl get pods \
  -n "${NAMESPACE}" \
  -o wide \
  > "${EVIDENCE_DIR}/pods-before.txt"

kubectl get deployment \
  greeter-greeter \
  -n "${NAMESPACE}" \
  -o yaml \
  > "${EVIDENCE_DIR}/deployment-before.yaml"

echo "==> Starting continuous traffic"

OUTPUT="${LOAD_LOG}" \
  extensions/resilience/load-test.sh \
  > /dev/null &

LOAD_PID=$!

cleanup() {
  kill "${LOAD_PID}" 2>/dev/null || true
}

trap cleanup EXIT

echo
echo "Continuous traffic is running."
echo "Trigger the Terraform/Helm rolling update now."
echo

kubectl rollout status \
  deployment/greeter-greeter \
  -n "${NAMESPACE}" \
  --timeout=180s \
  | tee "${EVIDENCE_DIR}/rollout-status.txt"

sleep 10

kubectl get pods \
  -n "${NAMESPACE}" \
  -o wide \
  > "${EVIDENCE_DIR}/pods-after.txt"

kubectl get deployment \
  greeter-greeter \
  -n "${NAMESPACE}" \
  -o yaml \
  > "${EVIDENCE_DIR}/deployment-after.yaml"

cleanup
trap - EXIT

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
