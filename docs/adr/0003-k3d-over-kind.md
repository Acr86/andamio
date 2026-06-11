# 0003. k3d over kind for the local cluster

Date: 2026-06

## Status

Accepted

## Context

The local platform needs a disposable Kubernetes cluster that satisfies four constraints at once. It must expose HTTP ingress on a developer laptop with zero manual wiring, because `make up` is advertised as the complete setup and every extra step is a place for the demo to die. It must import locally built images without a registry round-trip, because the golden-path demo builds and deploys in one pass. It must be the same tool on a laptop and in the `e2e-bootstrap` CI job, so the pipeline proves exactly what a contributor runs. And it must create and destroy fast, because the cluster is rebuilt constantly — every CI run, every `make demo`, every preview simulation via [scripts/preview-sim.sh](../../scripts/preview-sim.sh).

## Decision

k3d v5.8.3, running rancher/k3s v1.33.4-k3s1, created by [scripts/bootstrap.sh](../../scripts/bootstrap.sh). k3s bundles Traefik as its ingress controller, so Ingress resources work the moment the cluster is up; bootstrap maps the Traefik service to the host once and everything — Argo CD, services, preview environments — is reachable at `*.127.0.0.1.nip.io:8080` with no controller installation and no per-service port juggling. `k3d image import` moves locally built images straight into the cluster's containerd. The identical bootstrap script runs in the `e2e-bootstrap` job in [ci.yml](../../.github/workflows/ci.yml), and cluster create/delete is fast enough that `make down && make up` is a routine reset rather than a punishment.

## Alternatives considered

kind was the closest contender and lost on ingress friction. A working ingress on kind requires `extraPortMappings` declared at cluster-creation time, node labels, and a separately installed and patched ingress-nginx — every one of those steps is invisible plumbing that a reference repository would have to explain and a contributor could get subtly wrong. kind's image loading and CI story are fine; the ingress tax alone tipped the decision, because ingress is on the demo's critical path (the golden path ends in a `curl` through it, and preview URLs are the preview feature's entire user experience).

minikube lost on its driver story: behavior varies across docker/VM drivers and host platforms, startup is heavier, and "works on my driver" is exactly the class of support burden this repository should not carry.

docker-compose-only was considered for honesty's sake and rejected because it cannot demonstrate the platform's actual subject matter: there is no GitOps reconciliation loop to show, no namespaces for preview isolation, no Ingress objects, no admission surface for the policy gates. A compose file demos an application; this repository demos a platform.

## Consequences

The accepted cost is that k3s is not vanilla upstream Kubernetes. Two distortions are live in this repository today. First, the bundled Traefik is pinned by the k3s release, not by us — its version and configuration ride along with cluster upgrades, and ingress behavior here may differ from the ingress-nginx or cloud load balancers most readers run elsewhere. Second, k3s embeds the control-plane components (etcd's role is played by an embedded datastore; scheduler and controller-manager are not separate scrapable pods), so the kube-prometheus-stack control-plane scrape targets are explicitly disabled in [app-kube-prometheus-stack.yaml](../../deploy/argocd/apps/app-kube-prometheus-stack.yaml). Dashboards and alerts therefore exercise workload and platform telemetry only; anyone transplanting the observability stack to a managed or upstream cluster must re-enable and re-verify those targets. We judge both distortions acceptable because they sit at the edges of what the repository teaches — the GitOps loop, golden path, and preview lifecycle are unaffected — but they are real, and they are exactly the kind of gap ADR 0002's status labels exist to keep honest.
