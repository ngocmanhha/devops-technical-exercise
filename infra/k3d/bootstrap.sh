#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="what3words-exercise"
CONFIG="$(dirname "$0")/cluster.yaml"
IMAGE="greeter:local"

echo "==> Checking dependencies"

for command in docker k3d kubectl; do
  if ! command -v "${command}" >/dev/null 2>&1; then
    echo "ERROR: ${command} is required but not installed."
    exit 1
  fi
done

echo "==> Checking Docker"

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is not running."
  exit 1
fi

echo "==> Creating k3d cluster: ${CLUSTER_NAME}"

if k3d cluster list --no-headers | awk '{print $1}' | grep -qx "${CLUSTER_NAME}"; then
  echo "Cluster '${CLUSTER_NAME}' already exists."
else
  k3d cluster create \
    --config "${CONFIG}"
fi

echo "==> Setting kubectl context"

kubectl config use-context "k3d-${CLUSTER_NAME}"

echo "==> Waiting for Kubernetes nodes"

kubectl wait \
  --for=condition=Ready \
  nodes \
  --all \
  --timeout=120s

echo
echo "==> Cluster nodes"

kubectl get nodes -o wide

echo
echo "==> Cluster created successfully"
