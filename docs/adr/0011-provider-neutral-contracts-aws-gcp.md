# 0011. Provider-neutral contracts: mirrored GCP and AWS module pairs

Date: 2026-06

## Status

Accepted

## Context

The Terraform blueprint under [infra/terraform/](../../infra/terraform/) exists to show how this platform would land in a cloud: workload identity for CI, a serverless runtime that CI feeds by digest, a private database, an append-only audit sink. None of it is deployed — it is validated in CI ([terraform.yml](../../.github/workflows/terraform.yml)) and that is the point.

A single-provider blueprint invites a fair objection: "this is a GCP design, not a platform design." The architecture claims are provider-neutral — OIDC-federated CI identity, digest-pinned deploys, private-only data stores, immutable audit retention — and the way to prove that is to express the same contracts twice.

## Decision

Six module pairs, one per conceptual contract, mirrored across `infra/terraform/modules/gcp/` and `infra/terraform/modules/aws/`: `network`, `serverless-runtime`, `registry`, `cicd-identity`, `database`, `audit-log-sink`. The GCP composition is the most exercised path; the AWS tree is a faithful mirror that passes the same gates — the CI matrix runs fmt, validate, tflint and checkov over {aws,gcp} x {staging,prod}, and checkov is a hard gate for both.

"Same contract" means same inputs, same posture, same invariants — not same resources. The genuine deltas are kept, because they are where the providers actually differ:

| Contract | GCP | AWS | Genuine delta |
|---|---|---|---|
| CI identity | WIF pool + provider, pinned to repo and refs | IAM OIDC provider + role | GCP scopes trust at the pool/provider; AWS scopes trust per-role in each trust policy — N roles means N places to pin the repo |
| Serverless runtime | Cloud Run v2, `ignore_changes` on image | App Runner | Cloud Run has a native jobs primitive; App Runner has no job analog — one-off tasks become ECS RunTask, a second compute model |
| Audit sink | BigQuery sink, append-only, 7y | S3 Object Lock (compliance mode) + Firehose delivery | BigQuery enforces append-only at the dataset; S3 enforces WORM per-object via retention locks — different immutability mechanics, same retention claim |
| Database | Cloud SQL, private IP only, IAM auth, PITR | RDS, private subnets, IAM auth | RDS still requires a master password even with IAM auth; it is delegated to Secrets Manager (`manage_master_user_password`) rather than pretending the credential does not exist |
| Registry | Artifact Registry, cleanup policies (untagged 7d, keep last 20) | ECR lifecycle rules + scan-on-push | Near-equivalent; scan-on-push is an ECR toggle, Artifact Registry scanning is project-level |
| Network | Private VPC, no public ingress to data | Private VPC, no public ingress to data | Equivalent |

## Alternatives considered

A single abstraction layer — one `modules/runtime`, `modules/database`, etc., wrapping both providers behind shared variables. Rejected because cross-provider abstractions converge on the lowest common denominator: the wrapper either forbids what only one provider can express (Cloud Run jobs, Object Lock compliance mode) or leaks provider-specific variables through the "neutral" interface until it is two modules wearing one name. Mirrored-but-separate keeps each tree idiomatic, reviewable by someone who knows that provider, and honest about the deltas instead of hiding them.

## Consequences

- Two trees must be kept in sync, and nothing mechanical enforces semantic equivalence. The shared validate matrix proves both trees are *valid*, not that they still express the *same contract*. The only sync mechanism is review discipline plus the table above; drift between mirrors is possible and would be invisible to CI. This is the real cost of rejecting the abstraction layer, accepted with eyes open.
- The AWS tree is less exercised by construction. Bugs that only manifest at plan/apply time (not at validate time) are more likely to survive there.
- Every new contract costs two implementations and a table row, which deliberately raises the bar for adding modules — a feature for a reference blueprint, a tax for a real estate of thirty modules.
