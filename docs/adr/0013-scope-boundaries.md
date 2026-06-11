# 0013. Scope boundaries: what a production deployment adds

Date: 2026-06

## Status

Accepted

## Context

This is a reference platform: a single-node k3d cluster, one demo service, a Terraform blueprint that is validated but never applied. The value is in the shape of the system — golden path, GitOps, gates, evidence — not in operating it at scale. That creates a presentation problem: a reviewer who finds no NetworkPolicies cannot tell whether the author omitted them deliberately or does not know they exist.

This ADR is the scoping decision, recorded before publication. It is not a backlog, and none of these items are "coming later" — they are the line between a reference implementation and a production deployment, drawn on purpose.

## Decision

The following capabilities are deliberately out of scope. Each entry names the production answer, because knowing the answer is the point of writing the boundary down:

- **Log aggregation.** Pods log single-line JSON to stdout; nothing collects it. Production: Loki behind Grafana, or Cloud Logging when running on the GCP blueprint. The log format here is already structured precisely so that aggregation is an ingestion problem, not a refactor.
- **Progressive delivery.** Argo CD syncs plain Deployments; a bad image rolls out to 100%. Production: Argo Rollouts canary steps with analysis templates driven by the same Prometheus metrics the SLO alerts use, and metric-driven automatic rollback.
- **In-cluster secret management.** The local platform carries no real secrets, so nothing manages them. Production: external-secrets operator sourcing from Secret Manager (or the AWS mirror's Secrets Manager), with rotation owned outside the cluster. No secret material belongs in the GitOps repo, encrypted or otherwise.
- **Multi-node scheduling, ResourceQuotas, NetworkPolicies.** One k3d node makes spreading constraints meaningless, and the flat namespace model carries no tenant isolation. Production: multi-node pools, per-namespace quotas and LimitRanges, default-deny NetworkPolicies with explicit allows per service edge.
- **Real paging.** Alerts carry `severity: page` or `ticket` labels and runbook URLs, but no Alertmanager receiver routes them anywhere. Production: Alertmanager routing `page` to PagerDuty with escalation policies and `ticket` to the issue tracker — the labels and runbooks are designed as that routing's input.
- **Change-scoped previews.** [preview.yml](../../.github/workflows/preview.yml) builds all services for a labelled PR. Honest at two services, wasteful at twenty. Production: reuse the paths-filter routing already present in [ci.yml](../../.github/workflows/ci.yml) to build only changed services and overlay the rest from `:main` digests.
- **Registry GC verification.** Cleanup policies exist in the Terraform registry modules (untagged after 7 days, keep last 20), but nothing here ever observes them reclaiming space. Production: a periodic check that the policies actually fire — retention that has never been verified is a hope, not a control.

## Alternatives considered

Build it all. Every item above is well-understood and individually achievable, which is exactly the trap: each one adds components to bootstrap, documentation to write, and review surface that dilutes the parts this repository exists to demonstrate. A reference repo that chases production completeness never ships, and a half-operated Loki teaches less than a clearly drawn boundary. Rejected because the marginal item stopped clarifying the design and started obscuring it.

## Consequences

- Reviewers can mistake omissions for ignorance. That risk is accepted and mitigated head-on: this ADR and the capability map exist precisely so the boundary reads as a decision with known answers, not a gap. The mitigation only works for reviewers who read it.
- The local platform genuinely lacks these properties — a `severity: page` alert pages nobody, and a misbehaving pod can talk to anything in the cluster. Anyone forking this as a production starting point inherits this list as day-one work, not as polish.
