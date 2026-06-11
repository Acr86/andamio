# 0002. Runnable core, validated blueprint

Date: 2026-06

## Status

Accepted

## Context

A reference platform faces a credibility problem in both directions. If it is diagrams and prose only, nothing distinguishes it from a well-written blog post — anyone can draw boxes. If it maintains a live cloud footprint, a public repository inherits real money costs, a standing secret and OIDC trust surface, and a maintenance treadmill (provider API churn, security patching, drift) that has nothing to do with what the repository is trying to demonstrate. The repository needs a posture that maximizes provable claims per unit of operational liability, and it needs to be honest about where the proof stops.

## Decision

The repository is split into a runnable core and a validated blueprint, and every documented capability is labeled with one of three status levels.

Runnable: everything under the local platform — the k3d cluster, Argo CD app-of-apps, the golden-path scaffold, preview environments, the janitor, observability — runs from [scripts/bootstrap.sh](../../scripts/bootstrap.sh) and is exercised by this repository's own CI: the `e2e-bootstrap` job in [ci.yml](../../.github/workflows/ci.yml) bootstraps the cluster on the runner, deploys fx-rates via [scripts/deploy-local.sh](../../scripts/deploy-local.sh), and curls through the ingress. A claim labeled runnable is backed by a green pipeline, not by assertion.

Blueprint: the cloud tree under `infra/terraform/` (mirrored GCP and AWS modules plus staging/prod envs) is validated, never deployed. [terraform.yml](../../.github/workflows/terraform.yml) runs `terraform validate` across the full {provider} x {environment} matrix, plus tflint and checkov as a hard gate. [drift.yml](../../.github/workflows/drift.yml) carries a nightly `terraform plan -detailed-exitcode`, dormant behind the `ENABLE_CLOUD` repository variable, so the path to a real footprint is one variable flip, not a rewrite.

Design: things described and reasoned about but not encoded as artifacts at all.

The capability matrix in `docs/capabilities.md` uses these three labels consistently. The rule is simple: never label anything above its evidence.

## Alternatives considered

Deploying a real cloud footprint was seriously considered — it would make the Terraform claims as strong as the local ones. It loses on three grounds. Cost: Cloud SQL, RDS, NAT, and load balancers bill continuously for a repository nobody operates. Maintenance: a live environment demands patching, upgrades, and incident attention, which would either be done (stealing time from the platform content) or not done (a public, decaying deployment is worse than none). Secret surface: live deploys require cloud credentials or standing OIDC trust from a public repository, an attack surface with no compensating benefit.

Docs-only architecture was the other pole. It loses on credibility: the entire point of the repository is that the golden path, GitOps loop, preview lifecycle, and policy gates demonstrably work, and prose cannot demonstrate anything.

## Consequences

The consequence that hurts: the AWS and GCP paths never face live-API truth. `terraform validate` proves internal consistency, not deployability — API enablement ordering, IAM propagation delays, quota defaults, eventual-consistency races, and provider-specific argument quirks only surface on a real `apply`. Someone who lifts these modules into their own account may hit failures this repository's CI structurally cannot catch, and the blueprint label is the only warning they get. Mitigations, not cures: the hard tflint and checkov gates, mirrored module contracts across both providers (a shape that survives two providers' schemas is less likely to be wishful), and the dormant drift workflow that turns into a live plan the day someone supplies credentials.

A second cost is cognitive: a two-tier repository requires readers to check the label before trusting a claim, and requires authors to keep the labels truthful as code moves between tiers. That bookkeeping is permanent.
