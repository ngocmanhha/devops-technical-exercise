#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="what3words-exercise"

echo "==> Deleting k3d cluster: ${CLUSTER_NAME}"

if k3d cluster list --no-headers | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
  k3d cluster delete "${CLUSTER_NAME}"
else
  echo "Cluster '${CLUSTER_NAME}' does not exist."
fi

echo "==> Done"
