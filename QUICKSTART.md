# Quick Start — `solution-ext` Branch

Extended solution:

1. Containerization
2. Local multi-node Kubernetes
3. Gateway API + Envoy Gateway + Helm
4. Terraform dev/prod
5. Prometheus Operator observability
6. Resilience validation
7. GitHub Actions CI
8. Argo CD GitOps

More details are available in `./docs/1...8`.

## Prerequisites

```bash
docker version
k3d version
kubectl version --client
helm version
terraform version
jq --version
```

Docker must be running.

## 1. Clone and checkout

```bash
git clone <REPOSITORY_URL>
cd what3words-exercise
git checkout solution-ext
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

```bash
helm install envoy-gateway \
  oci://docker.io/envoyproxy/gateway-helm \
  --version v1.9.0 \
  --namespace envoy-gateway-system \
  --create-namespace
```

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

## 5. Install kube-prometheus-stack

```bash
helm repo add prometheus-community \
  https://prometheus-community.github.io/helm-charts

helm repo update
```

```bash
helm upgrade \
  --install \
  kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --values extensions/observability/kube-prometheus-stack/values.yaml \
  --wait \
  --timeout 5m
```

Verify:

```bash
kubectl get pods -n monitoring
kubectl get crd | grep monitoring.coreos.com
```

## 6. Validate and package the Helm chart

```bash
helm lint charts/greeter
```

```bash
helm template \
  greeter \
  charts/greeter \
  --namespace greeter-prod
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

## 7. Deploy dev and prod with Terraform

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

```bash
cd ..
```

Verify:

```bash
kubectl get pods -n greeter-dev -o wide
kubectl get pods -n greeter-prod -o wide
kubectl get httproute -A
kubectl get servicemonitor -A
kubectl get prometheusrule -A
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

## 8. Verify Prometheus monitoring

Port-forward Prometheus:

```bash
kubectl port-forward \
  -n monitoring \
  svc/kube-prometheus-stack-prometheus \
  9090:9090
```

Check the Greeter rule group:

```bash
curl -s \
  'http://localhost:9090/api/v1/rules?type=alert' \
  | jq '.data.groups[] | select(.name == "greeter.rules")'
```

Generate intentional errors in another terminal:

```bash
while true; do
  curl \
    -s \
    -o /dev/null \
    -H 'Host: prod.greeter.local' \
    http://localhost:8080/boom

  sleep 0.1
done
```

Check the alert:

```bash
curl -s \
  http://localhost:9090/api/v1/alerts \
  | jq '.data.alerts[] | select(.labels.alertname == "GreeterHigh5xxErrorRate")'
```

Stop the error loop when finished.

## 9. Run resilience validation

Node-drain test:

```bash
./extensions/resilience/node-drain-test.sh
```

Review:

```bash
cat extensions/resilience/evidence/node-drain/summary.txt
```

For rolling-update testing:

```bash
OUTPUT="extensions/resilience/evidence/rolling-update/requests.csv" \
SUMMARY_OUTPUT="extensions/resilience/evidence/rolling-update/summary.txt" \
./extensions/resilience/load-test.sh
```

Trigger the rollout through the normal deployment workflow and stop the load generator with `Ctrl+C`.

See:

[Resilence Validation - Extension D](./docs/6.%20Resilence%20Validation%20-%20Extension%20D.md)

for the complete sequence.

## 10. CI

GitHub Actions:

```text
.github/workflows/ci.yaml
```

The workflow checks:

```text
Go tests + coverage
Mock Sonar stage
Docker build
Helm validation
Terraform validation
ShellCheck
```

Push to a configured branch or open a pull request to run it.

## 11. Install Argo CD

```bash
kubectl create namespace argocd
```

```bash
helm repo add argo \
  https://argoproj.github.io/argo-helm

helm repo update
```

```bash
helm upgrade \
  --install \
  argocd \
  argo/argo-cd \
  --namespace argocd \
  --wait \
  --timeout 5m
```

Verify:

```bash
kubectl get pods -n argocd
```

## 12. Apply GitOps configuration

Before enabling Argo CD ownership, avoid having Terraform and Argo CD continuously reconcile the same Greeter resources.

Apply the repository's GitOps manifests:

```bash
kubectl apply -f extensions/gitops/applications
```

Verify:

```bash
kubectl get applications -n argocd
```

Expected:

```text
Synced
Healthy
```

Optional UI:

```bash
kubectl port-forward \
  -n argocd \
  svc/argocd-server \
  8081:443
```

## 13. Demonstrate GitOps

Change a Git-managed value and commit/push:

```bash
git add .
git commit -m "test: update dev configuration through GitOps"
git push
```

Watch:

```bash
kubectl get applications \
  -n argocd \
  -w
```

Verify the changed deployment:

```bash
curl \
  -H 'Host: dev.greeter.local' \
  http://localhost:8080/
```

## 14. Cleanup

Remove application resources according to the active ownership model.

If Terraform still owns them:

```bash
cd terraform
terraform destroy
```

See cluster cleanup in:

[2. Local K8S Cluster.md](./docs/2.%20Local%20K8S%20Cluster.md)

## Detailed documentation

- [Containerized](./docs/1.%20Containerized.md)
- [Local K8S Cluster](./docs/2.%20Local%20K8S%20Cluster.md)
- [Helm Deployment](./docs/3.%20Helm%20Deployment.md)
- [Terraform](./docs/4.%20Terraform.md)
- [Observability](./docs/5.%20Observability%20-%20Extension%20B.md)
- [Resilence](./docs/6.%20Resilence%20Validation%20-%20Extension%20D.md)
- [Continuous Integration](./docs/7.%20Continuous%20Integration%20-%20Extension%20A.md)
- [GitOps](./docs/8.%20Gitops%20-%20Extension%20C.md)
