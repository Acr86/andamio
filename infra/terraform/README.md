# Terraform

Infrastructure blueprint for the platform: six opinionated modules per cloud,
composed into per-environment roots.

```
infra/terraform/
├── .tflint.hcl              # shared lint policy (terraform + aws + google rulesets)
├── modules/
│   ├── gcp/                 # network, database, serverless-runtime, registry,
│   │                        # cicd-identity, audit-log-sink
│   └── aws/                 # the same six concerns, AWS-native
└── envs/
    ├── staging/{gcp,aws}/   # disposable: no HA, no deletion protection, short retention
    └── prod/{gcp,aws}/      # protected: HA, deletion protection, 7-year audit retention
```

## Posture: validated, not deployed

This tree is validated in CI (`terraform fmt -check`, `terraform validate`,
`tflint`, `checkov`) but never applied; it is a reference architecture, not a
running estate. Going live would take three things that are deliberately
absent here: a real state backend (the `gcs`/`s3` backend blocks in each
root's `versions.tf` are commented out, so state is local and throwaway), real
project and account identifiers (`project_id`, the AWS account implied by the
provider credentials), and out-of-band secrets (the GitHub repository wired
into the OIDC trust, application secrets in Secret Manager / Secrets Manager —
no secret material is ever a Terraform input in this design). The deployment
flow the roots are written for: staging auto-applies on merge to `main`,
production applies the same plan behind a manual approval gate.

## AWS / GCP equivalence

The two trees implement the same six platform concerns. The table lists each
pair and the deltas that are real architectural differences, not naming.

| Concern | GCP module | AWS module | Genuine deltas |
|---|---|---|---|
| Private network | `gcp/network` | `aws/network` | GCP attaches managed services via a Private Services Access peering range (one per VPC); AWS uses subnet placement plus security groups. AWS runs one NAT gateway (per-AZ NAT is a cost/availability tradeoff left visible); Cloud NAT is regional by construction. |
| PostgreSQL | `gcp/database` | `aws/database` | HA is Cloud SQL `REGIONAL` vs RDS Multi-AZ — same idea, different failover mechanics. Ingress: Cloud SQL is reachable only by private IP inside the VPC (no SG concept); RDS ingress is security-group-scoped per source. RDS generates and owns the master password in Secrets Manager (never in state); Cloud SQL leans on IAM database authentication instead. |
| Serverless runtime | `gcp/serverless-runtime` | `aws/serverless-runtime` | Cloud Run scales to zero; App Runner's floor is 1 instance — staging idle cost is structural on AWS. Cloud Run has first-class jobs (the migration job is the same module); App Runner has no job primitive, so migrations need another vehicle when porting. Ingress granularity differs: Cloud Run offers internal / internal-LB / all, App Runner is effectively public or VPC-private. |
| Container registry | `gcp/registry` | `aws/registry` | Same retention opinions (untagged images are garbage after days, keep last N tagged). Artifact Registry cleanup policies are repo-level and condition-based; ECR lifecycle policies are rule-priority JSON with tag-prefix matching. ECR adds `force_delete` semantics Artifact Registry lacks. |
| CI/CD identity | `gcp/cicd-identity` | `aws/cicd-identity` | Both are keyless GitHub OIDC. GCP federates through a Workload Identity *pool + provider* with a CEL `attribute_condition` (exact ref match only) and a service account impersonation binding; AWS trusts per-role via the assume-role policy's `sub` condition, where `StringLike` wildcards (e.g. `refs/tags/v*`) are possible. AWS allows exactly one OIDC provider per issuer per account — it is shared account state in a way the GCP pool is not. |
| Audit log sink | `gcp/audit-log-sink` | `aws/audit-log-sink` | GCP exports to a BigQuery dataset: immediately queryable, retention via partition expiry, but not true WORM (that would need GCS Bucket Lock). AWS streams CloudWatch → Firehose → S3 with Object Lock: genuine WORM (COMPLIANCE mode binds even root), but querying the archive requires Athena on top. The hot/cold split is explicit on AWS (log group vs bucket) and implicit on GCP (Logging vs BigQuery). |

## Conventions

- Modules pin `required_version = ">= 1.9"` and a pessimistic provider
  constraint (`~> 6.0` for both `hashicorp/google` and `hashicorp/aws`);
  provider *blocks* exist only in the env roots.
- Environment deltas live in root arguments, never inside modules: a module
  has one behavior, the root decides how careful to be with it.
- Validate locally the same way CI does:

```sh
export TF_PLUGIN_CACHE_DIR="$PWD/.tfcache"
terraform -chdir=infra/terraform/envs/staging/gcp init -backend=false -input=false
terraform -chdir=infra/terraform/envs/staging/gcp validate
tflint --chdir=infra/terraform/envs/staging/gcp --config "$PWD/infra/terraform/.tflint.hcl"
```
