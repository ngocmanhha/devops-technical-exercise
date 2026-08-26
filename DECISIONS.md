# DECISIONS.md

## Overview

This solution was designed to satisfy the exercise with a strong focus on:

- Reproducibility
- Minimal but production-minded Kubernetes configuration
- Clear separation between application and platform responsibilities
- Local-first development with no cloud dependencies
- Availability during pod and worker-node disruption
- Immutable deployment artifacts
- Environment-specific configuration without duplication

The implementation intentionally avoids adding components that do not materially improve the exercise.

---

## 1. Container Image

### Decision

Use a multi-stage Docker build with a statically compiled Go binary.

The application is built with:

```text
CGO_ENABLED=0
```

and supports:

```text
linux/arm64
linux/amd64
```

The runtime image contains only what is required to execute the application and runs as a non-root user.

### Why

The exercise must run locally across different developer machines, including Apple Silicon and AMD64 systems.

Disabling CGO improves portability and also avoids the macOS native Go toolchain issue mentioned in the exercise.

The final runtime image does not need:

```text
Go compiler
source code
build tools
development dependencies
```

This reduces image size and runtime attack surface.

### Considered and Rejected

A single-stage Go image was considered but rejected because it would ship the compiler and build environment into the runtime image.

Building a macOS binary was also rejected because the Kubernetes environment runs Linux containers regardless of whether the developer workstation is macOS.

### Production Consideration

For a production system I would additionally:

- Build images through CI
- Use immutable image digests
- Generate an SBOM
- Scan images for vulnerabilities
- Sign container images
- Store images in an authenticated container registry

---

## 2. Local Kubernetes Distribution

### Decision

Use **k3d** with:

```text
1 server/control-plane
2 agent/worker nodes
```

Cluster name:

```text
what3words-exercise
```

### Why

The exercise requires a local multi-node Kubernetes environment with at least two worker nodes.

k3d was selected because it provides:

- Fast cluster creation
- Low local resource usage
- Multi-node support
- ARM64 and AMD64 support
- Simple Docker integration
- Simple local image import
- Reproducible configuration

### Considered and Rejected

#### kind

kind was considered and would also satisfy the exercise.

It is closer to upstream Kubernetes, but k3d was selected because cluster creation and local image workflows are lightweight and convenient for this exercise.

#### Minikube

Minikube supports multi-node clusters but introduces more driver-specific behavior than necessary here.

### Trade-off

k3d runs k3s rather than a full upstream Kubernetes distribution.

I accepted this trade-off because the application uses standard Kubernetes APIs and does not depend on k3s-specific functionality.

### Production Consideration

For a production service I would use a managed or dedicated Kubernetes platform with highly available control-plane nodes and multiple failure domains.

---

## 3. Application Packaging

### Decision

Use a manually written Helm chart located at:

```text
charts/greeter
```

### Why

The application has multiple environment-specific settings, including:

```text
GREETING_NAME
replicaCount
resources
gateway.hostnames
```

Helm provides a clean way to keep one Kubernetes package while supplying different environment values.

The chart was intentionally written manually rather than using the default `helm create` scaffold.

### Considered and Rejected

Kustomize was considered.

Kustomize would work well for simple overlays, but Helm was selected because Terraform can pass environment-specific values directly into the same package without maintaining separate overlays.

### Trade-off

Helm introduces templating complexity.

To reduce that complexity, the chart contains only Kubernetes resources that are required by the application.

---

## 4. Liveness and Readiness

### Decision

Use:

```text
/healthz -> liveness
/readyz  -> readiness
```

### Why

These endpoints intentionally model different application states.

During startup:

```text
/healthz = 200
/readyz  = 503
```

until the warm-up period completes.

Using `/readyz` as a liveness probe would be incorrect because Kubernetes could restart a healthy process while it is still warming up.

### Shutdown Behavior

On `SIGTERM`, the application immediately becomes unready while continuing to serve existing traffic.

This behavior is used directly rather than adding an artificial Kubernetes `preStop` delay.

---

## 5. Graceful Termination

### Decision

Use:

```text
terminationGracePeriodSeconds = 40
```

### Why

The default application shutdown behavior allows:

```text
10 seconds shutdown delay
+
20 seconds drain timeout
+
10 seconds safety margin
=
40 seconds
```

### Considered and Rejected

A `preStop` hook with `sleep` was considered but rejected.

The application already implements the required delay after receiving `SIGTERM`.

Adding another sleep would duplicate that logic and unnecessarily delay delivery of `SIGTERM`.

---

## 6. Rolling Update Strategy

### Decision

Use:

```yaml
maxUnavailable: 0
maxSurge: 1
```

### Why

The application can require 30 seconds before becoming ready.

During an update, an existing ready replica should therefore remain available until a replacement pod completes its warm-up period.

This configuration favors availability over minimum temporary resource consumption.

### Trade-off

The cluster temporarily runs an additional pod during deployment.

For this service, that is preferable to intentionally reducing availability.

---

## 7. Replica Placement

### Decision

Use two mechanisms:

```text
Node affinity
Topology spread constraints
```

Application pods are excluded from the control-plane node and spread across worker nodes using:

```text
kubernetes.io/hostname
```

### Why

Two replicas alone do not guarantee resilience.

Without scheduling constraints, Kubernetes could place both replicas on one worker node.

The desired placement is:

```text
Agent 0        Agent 1
   │              │
   ▼              ▼
Replica 1      Replica 2
```

This supports the requirement that the application stay available during the loss of one worker node.

### Trade-off

Using:

```text
whenUnsatisfiable: DoNotSchedule
```

prioritizes failure-domain separation over scheduling flexibility.

For this exercise that is intentional because node-loss resilience is an explicit requirement.

---

## 8. PodDisruptionBudget

### Decision

Use:

```text
minAvailable = 1
```

### Why

With two production replicas, at least one application pod should remain available during voluntary disruption such as a node drain.

### Limitation

A PodDisruptionBudget does not protect against sudden node failure.

It complements replica spreading but does not replace it.

---

## 9. Gateway API

### Decision

Use Kubernetes **Gateway API** rather than the legacy Ingress API.

### Why

Gateway API provides clearer separation between platform infrastructure and application routing.

The ownership model is:

```text
Platform
├── GatewayClass
└── Gateway

Application
└── HTTPRoute
```

This is closer to how shared Kubernetes networking is typically managed in larger environments.

### Considered and Rejected

The built-in k3s Traefik ingress controller would have been simpler.

It was rejected in favor of Gateway API because the latter provides a cleaner and more modern traffic-management model.

### Trade-off

Gateway API with an external implementation introduces additional components compared with using the bundled ingress controller.

For a time-boxed exercise this is additional complexity, so the Gateway configuration was intentionally kept small.

---

## 10. Envoy Gateway

### Decision

Use:

```text
Envoy Gateway v1.9.0
```

as the Gateway API implementation.

### Why

Envoy Gateway provides a standards-based Gateway API implementation without requiring application-specific ingress annotations.

The version is explicitly pinned to improve reproducibility.

### Architecture

```text
k3d Load Balancer
        │
        ▼
    Envoy Proxy
        │
        ▼
     Gateway
        │
        ▼
    HTTPRoute
        │
        ▼
     Service
        │
        ▼
      Pods
```

### Production Consideration

In a production platform, the Gateway lifecycle would normally be owned independently by platform infrastructure rather than deployed together with a single application.

---

## 11. Service Exposure

### Decision

Keep the application Service as:

```text
ClusterIP
```

and expose traffic through Gateway API.

### Why

The application Service should handle internal service discovery.

External traffic management belongs to the Gateway layer.

### Considered and Rejected

#### NodePort

Rejected because it couples the application directly to a host port and is less representative of a production traffic-entry architecture.

#### LoadBalancer per Application

Rejected because it would introduce unnecessary infrastructure for this local exercise.

---

## 12. Environment Routing

### Decision

Use environment-specific Gateway hostnames:

```text
dev.greeter.local
prod.greeter.local
```

The Helm chart accepts:

```text
gateway.hostnames
```

as a list.

### Why

Both environments attach to the same shared Gateway.

Without hostname separation, two routes matching `/` could overlap.

Host-based routing clearly separates:

```text
dev.greeter.local
        │
        ▼
greeter-dev
```

from:

```text
prod.greeter.local
        │
        ▼
greeter-prod
```

Using a hostname list also allows future aliases without changing the chart structure.

---

## 13. Local Container Images

### Decision

Import the locally built image directly into k3d.

### Why

The exercise requires everything to run locally and does not require a remote registry.

Introducing Docker Hub, GHCR, ECR, or another registry would add credentials and external dependencies without improving the core assessment.

### Production Consideration

Production images would be:

```text
CI built
versioned
scanned
signed
pushed to a registry
deployed by digest
```

---

## 14. Helm Chart Signing

### Decision

Package and sign the Helm chart using GPG provenance.

Artifacts:

```text
greeter-0.1.0.tgz
greeter-0.1.0.tgz.prov
```

### Why

Signing demonstrates that the deployment artifact can be independently verified before installation.

The public signing key can be committed while the private signing key remains outside the repository.

### Trade-off

For a local exercise, chart signing is more security infrastructure than strictly required.

I included it because artifact provenance is useful in a real deployment pipeline and inexpensive to demonstrate.

### Production Consideration

In production I would move signing into CI/CD and use centrally managed signing credentials rather than a developer workstation key.

I would also consider OCI artifact signing using a supply-chain mechanism such as Sigstore/Cosign.

---

## 15. Terraform Environment Model

### Decision

Use one reusable Terraform deployment model for:

```text
dev
prod
```

rather than separate duplicated infrastructure definitions.

### Why

The exercise requires two environments that differ at least in greeting name and replica count without duplicating configuration.

The environments therefore vary by data:

```text
dev
├── GREETING_NAME
├── replicaCount
├── resources
└── gateway.hostnames

prod
├── GREETING_NAME
├── replicaCount
├── resources
└── gateway.hostnames
```

while sharing the same deployment logic.

### Result

The same signed Helm package is deployed into:

```text
greeter-dev
greeter-prod
```

with different runtime values.

### Production Consideration

For a larger platform I would likely separate Terraform state by environment or deployment boundary rather than keeping development and production resources in one state.

---

## 16. Separate Kubernetes Namespaces

### Decision

Deploy environments into:

```text
greeter-dev
greeter-prod
```

### Why

Namespaces provide a simple operational and resource boundary while still allowing both environments to share cluster-level infrastructure.

### Trade-off

Namespaces are not equivalent to full security or infrastructure isolation.

For a production system, dev and prod might be placed in separate clusters or cloud accounts depending on security and regulatory requirements.

---

## 17. Terraform Scope

### Decision

Terraform deploys the application package but does not build or sign it.

### Why

Responsibilities are intentionally separated:

```text
Docker
└── Build application

Helm
├── Package Kubernetes resources
└── Create signed artifact

Terraform
└── Deploy environments
```

Terraform consumes an existing deployment artifact rather than acting as a build system.

This also means the artifact can be verified independently before Terraform uses it.

---

## 18. Resource Requests and Limits

### Decision

Define explicit CPU and memory requests and limits and allow them to vary by environment.

### Why

Requests give Kubernetes meaningful scheduling information.

Limits prevent an individual workload from consuming unbounded node resources.

### Trade-off

The values in this exercise are estimates rather than values derived from real load testing.

### Production Consideration

Production values should be based on:

- Observed workload metrics
- Load tests
- Historical utilization
- Capacity planning
- SLO requirements

---

## 19. Decisions I Am Least Certain About

### Envoy Gateway for This Exercise

Gateway API and Envoy Gateway are technically appropriate, but they add more moving parts than the exercise strictly requires.

A simpler solution using the built-in Traefik ingress controller would likely be faster to reproduce.

I chose Envoy Gateway because the separation between `Gateway` and `HTTPRoute` better represents the architecture I would prefer for a shared Kubernetes platform.

If the exercise were strictly optimized for minimum setup time, I would reconsider this choice.

### k3d Versus kind

Both are reasonable.

kind provides an environment closer to upstream Kubernetes, while k3d is lighter and provides a convenient local multi-node workflow.

I selected k3d primarily for developer experience and fast reproducibility.

### PodDisruptionBudget with Dev Replica Count of One

A PDB is useful for the production environment with multiple replicas.

For a single-replica development environment, disruption guarantees are inherently limited.

If the chart required production-grade availability in every environment, I would enforce a minimum replica count of two whenever the PDB is enabled.

---

## 20. Ambiguities and Assumptions

### Meaning of "Survive the Loss of a Single Node"

I interpreted this as application availability during loss of one worker node rather than control-plane high availability.

Therefore the cluster uses:

```text
1 control-plane
2 workers
```

and application replicas are spread across the two workers.

A production Kubernetes control plane would require additional redundancy.

### External Cluster Access

The exercise does not prescribe how the application must be exposed.

I interpreted external access as accessibility from the host machine running the local cluster.

This is implemented through:

```text
localhost
→ k3d
→ Envoy
→ Gateway
→ HTTPRoute
→ Service
```

### Environment Isolation

The exercise requires dev and prod configurations but does not require separate clusters.

I therefore deployed them into separate namespaces within the same local cluster.

---

## 21. Deliberately Left Out

The following were intentionally excluded from the core implementation.

### TLS

The local Gateway currently uses HTTP.

Production would use HTTPS with certificate automation, likely through:

```text
cert-manager
Gateway TLS listeners
managed certificates
```

TLS was omitted to keep the exercise focused on deployment behavior rather than certificate plumbing.

### NetworkPolicy

Network policies would be valuable in production but were not required to demonstrate the core application behavior.

### External Secrets

The application currently has no sensitive configuration requiring a secrets-management solution.

I therefore did not introduce Vault, External Secrets Operator, or cloud secret stores.

### Horizontal Pod Autoscaler

There is insufficient workload data to define meaningful autoscaling thresholds.

Static replicas are sufficient to demonstrate the requested environment differences and node availability.

### Persistent Storage

The service is stateless and does not require persistent volumes.

### Service Mesh

A service mesh would add significant complexity with no meaningful benefit for this single-service exercise.

### Cloud Infrastructure

No cloud resources were introduced because the exercise explicitly requires a local-only implementation.

---

## 22. What I Would Do Differently in Production

For a real production-facing service I would add:

- Managed Kubernetes or highly available control-plane infrastructure
- Multiple availability zones
- Container registry
- Immutable image digests
- CI/CD pipeline
- Automated vulnerability scanning
- SBOM generation
- Container image signing
- Automated Helm artifact signing
- TLS
- DNS
- NetworkPolicies
- Centralized secrets management
- Prometheus monitoring
- Alerting
- Centralized logging
- Distributed tracing where appropriate
- Horizontal Pod Autoscaling
- Load and resilience testing
- Backup and disaster-recovery planning
- Separate production Terraform state
- Remote state locking
- Policy-as-code checks
- Automated deployment promotion

---

## 23. Extension Prioritization

If additional exercise time remains, I would prioritize the extensions in the following order.

### 1. Observability

The application already exposes:

```text
/metrics
```

and `/boom` exists specifically to generate failures.

Prometheus scraping plus a meaningful alert provides immediate operational value and demonstrates that the service can be monitored after deployment.

### 2. Prove It Survives

I would run continuous requests while:

```text
draining a worker node
performing a rolling update
```

and record request results.

This directly validates two of the most important design decisions:

```text
topology spreading
graceful shutdown
```

### 3. CI Pipeline

A CI workflow would automate:

```text
Go tests
Docker build
Helm lint
Helm template
Terraform fmt
Terraform validate
artifact packaging
```

This is valuable, but the implementation is already locally reproducible without CI.

### 4. GitOps

GitOps would be useful in a real platform, but for this exercise it provides less incremental evidence than observability or resilience testing.

It also introduces repository authentication and controller setup that could consume a disproportionate amount of the available time.

---

## 24. Final Architecture

```text
                      Developer / CI
                            │
                            ▼
                       Go Source
                            │
                            ▼
                       Docker Build
                            │
                            ▼
                       greeter image
                            │
                            ▼
                       Helm Chart
                            │
                     package + sign
                            │
                            ▼
                  greeter-0.1.0.tgz
                            │
                            ▼
                        Terraform
                            │
                 ┌──────────┴──────────┐
                 │                     │
                 ▼                     ▼
                DEV                   PROD
                 │                     │
          greeter-dev             greeter-prod
                 │                     │
            1 replica               2 replicas
                 │                     │
                 ▼                     ▼
            HTTPRoute               HTTPRoute
                 │                     │
      dev.greeter.local     prod.greeter.local
                 │                     │
                 └──────────┬──────────┘
                            │
                            ▼
                   what3words-gateway
                            │
                            ▼
                       Envoy Proxy
                            │
                            ▼
                     k3d Load Balancer
                            │
                            ▼
                       Local Machine
```

## Summary

The main design principle throughout this exercise was to keep the solution **small enough to understand and reproduce while still demonstrating production-oriented behavior**.

The implementation therefore prioritizes:

```text
Reproducibility
Availability
Correct application lifecycle handling
Configuration separation
Immutable artifacts
Environment reuse
Modern Kubernetes networking
Clear ownership boundaries
```

Where additional infrastructure was not necessary to prove those behaviors, it was deliberately left out.
