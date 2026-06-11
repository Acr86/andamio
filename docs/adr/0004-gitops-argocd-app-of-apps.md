# 0004. GitOps with Argo CD app-of-apps

Date: 2026-06

## Status

Accepted

## Context

The platform manages several classes of workload with very different lifecycles: long-lived services in the `services` namespace, per-PR preview environments that appear and disappear daily, the platform's own components (preview janitor, monitoring stack), and observability configuration. Wiring each of these into a push-based deploy script means every new service, and every new preview, needs a pipeline edit — and the cluster's actual state is whatever the last script run left behind. Nothing detects drift, nothing repairs it, and removing a manifest from the repo removes nothing from the cluster.

The platform's core promise — merge a scaffolded service and it deploys, open a labelled PR and a preview environment exists — requires that the repository itself be the deployment interface, with a reconciler closing the loop.

## Decision

A human applies exactly one thing, once: the root Application ([deploy/argocd/root-app.yaml](../../deploy/argocd/root-app.yaml)), installed by `scripts/bootstrap.sh` during `make up`. The root app points at `deploy/argocd/apps/`, and everything else is generated:

- [applicationset-services.yaml](../../deploy/argocd/apps/applicationset-services.yaml) runs a git directory generator over `deploy/kustomize/services/*/overlays/local`, producing one Application per service. Merging a scaffolded service deploys it with zero Argo CD edits.
- [applicationset-previews.yaml](../../deploy/argocd/apps/applicationset-previews.yaml) is a matrix of the GitHub PR generator (label `preview`) and the same directory layout, producing one namespace and environment per open PR.
- Helm and kustomize Applications cover the monitoring stack, observability config, and the janitor.

All generated Applications run with automated sync, prune, and self-heal. The cluster converges to the repo; manual mutations are reverted; deletions in git are deletions in the cluster.

One deliberate escape hatch exists: `make deploy-local` ([scripts/deploy-local.sh](../../scripts/deploy-local.sh)) builds an image, imports it into k3d, and applies manifests directly — bypassing GitOps for pre-commit inner-loop iteration. This is acceptable because it only touches the `services` namespace, which self-heal converges back to the committed state on the next sync. The escape hatch can never create persistent drift; at worst a developer's uncommitted experiment survives one sync interval.

## Alternatives considered

**Plain `kubectl apply` from CI.** Simple, no new component. Rejected: drift is invisible between pipeline runs, there is no reconciliation when someone edits the cluster by hand, resource deletion requires hand-rolled prune logic, and CI must hold cluster credentials — the inverse of the pull model.

**Flux.** A credible alternative, not a strawman: its Kustomize and Helm controllers cover the steady-state GitOps loop just as well, and its multi-tenancy story is arguably cleaner. It loses narrowly on one feature: the ApplicationSet PR generator is exactly the preview-environment mechanism this platform centers on. In Flux, per-PR environments are assembled from third-party tooling or a custom controller; in Argo CD it is one declarative resource the repo already contains.

## Consequences

- Argo CD is a platform single point of failure. When it is down, nothing deploys, previews neither appear nor update, and orphan detection in the janitor (which keys off Application existence) degrades — only the janitor's 30-minute grace window keeps a transient outage from being mistaken for closed PRs.
- Sync cadence bounds freshness everywhere: the default ~3-minute reconciliation plus the PR generator's 300-second requeue means a merge or a `preview` label can take several minutes to become a running environment. This is accepted; tightening it trades API-rate pressure for latency.
- Self-heal reverts manual hotfixes by design. On-call must internalize that the only durable change path is a commit — fighting the reconciler during an incident wastes minutes.
