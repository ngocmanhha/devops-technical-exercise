# Quick Start — `solution` Branch

Core solution:

1. Containerize the Go service
2. Create a local multi-node Kubernetes cluster
3. Install Gateway API / Envoy Gateway and deploy with Helm
4. Deploy `dev` and `prod` with Terraform

More details are available in `./docs/1...4`.

## Prerequisites

```bash
docker version
k3d version
kubectl version --client
helm version
terraform version
```

Docker must be running.

## 1. Clone and checkout

```bash
git clone <REPOSITORY_URL>
cd what3words-exercise
git checkout solution
```

## 2. Build the application image

Apple Silicon:

```bash
docker build \
  --platform linux/arm64 \
  -t greeter:exercise \
  .
```

AMD64:

```bash
docker build \
  --platform linux/amd64 \
  -t greeter:exercise \
  .
```

## 3. Create the local Kubernetes cluster

```bash
./infra/k3d/bootstrap.sh
```

Verify:

```bash
kubectl config use-context k3d-what3words-exercise
kubectl get nodes
```

Import the image:

```bash
k3d image import \
  greeter:exercise \
  --cluster what3words-exercise
```

## 4. Install Gateway API / Envoy Gateway

Install Envoy Gateway `v1.9.0`:

```bash
helm install envoy-gateway \
  oci://docker.io/envoyproxy/gateway-helm \
  --version v1.9.0 \
  --namespace envoy-gateway-system \
  --create-namespace
```

Wait for it:

```bash
kubectl wait \
  --namespace envoy-gateway-system \
  --for=condition=Available \
  deployment/envoy-gateway \
  --timeout=5m
```

Install the Gateway API resources from:

```text
k8s/manifests/gateway-class.yaml
k8s/manifests/gateway.yaml
```

```bash
kubectl apply -f k8s/manifests/gateway-class.yaml
kubectl apply -f k8s/manifests/gateway.yaml
```

Verify:

```bash
kubectl get gatewayclass
kubectl get gateway -n envoy-gateway-system
kubectl api-resources --api-group=gateway.networking.k8s.io
```

## 5. Validate and package the Helm chart

```bash
helm lint charts/greeter
```

```bash
helm template \
  greeter \
  charts/greeter \
  --namespace greeter
```

Package:

```bash
mkdir -p dist

helm package \
  charts/greeter \
  --destination dist
```

Expected:

```text
dist/greeter-0.1.0.tgz
```

## 6. Deploy dev and prod with Terraform

```bash
cd terraform
```

```bash
terraform init
terraform fmt -recursive -check
terraform validate
terraform plan
terraform apply
```

Return to the repository root:

```bash
cd ..
```

## 7. Verify

```bash
helm list --all-namespaces
```

```bash
kubectl get pods -n greeter-dev -o wide
kubectl get pods -n greeter-prod -o wide
```

```bash
kubectl get httproute -n greeter-dev
kubectl get httproute -n greeter-prod
```

Get the Envoy service created for the Gateway and port-forward it:

```bash
ENVOY_SERVICE=$(kubectl get svc \
  -n envoy-gateway-system \
  -l gateway.envoyproxy.io/owning-gateway-namespace=envoy-gateway-system,gateway.envoyproxy.io/owning-gateway-name=what3words-gateway \
  -o jsonpath='{.items[0].metadata.name}')

kubectl port-forward \
  -n envoy-gateway-system \
  svc/${ENVOY_SERVICE} \
  8080:80
```

Keep the port-forward running, then test from another terminal.

Dev:

```bash
curl \
  -H 'Host: dev.greeter.local' \
  http://localhost:8080/
```

Prod:

```bash
curl \
  -H 'Host: prod.greeter.local' \
  http://localhost:8080/
```

## 8. Cleanup

```bash
cd terraform
terraform destroy
```

See the cluster cleanup instructions in:

[2. Local K8S Cluster.md](./docs/2.%20Local%20K8S%20Cluster.md)

## Detailed documentation

- [Containerized](./docs/1.%20Containerized.md)
- [Local K8S Cluster](./docs/2.%20Local%20K8S%20Cluster.md)
- [Helm Deployment](./docs/3.%20Helm%20Deployment.md)
- [Terraform](./docs/4.%20Terraform.md)
