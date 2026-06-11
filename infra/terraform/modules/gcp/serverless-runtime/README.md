# serverless-runtime

Opinionated Cloud Run runtime for a single workload: a `google_cloud_run_v2_service` with direct VPC egress and internal-only ingress, an optional companion `google_cloud_run_v2_job` (same image, identity, and network — typically database migrations), and a dedicated service account that this module deliberately grants nothing. The module encodes a strict ownership split with CI: Terraform defines the runtime contract (identity, network, scaling, resources, configuration), while the CI pipeline owns the container image digest via build-once/promote.

## Usage

```hcl
module "orders_api" {
  source = "../../modules/gcp/serverless-runtime"

  project_id = "platform-prod-4711"
  region     = "europe-west1"
  name       = "orders-api"
  image      = "europe-west1-docker.pkg.dev/platform-prod-4711/services/orders-api:bootstrap"

  network_id = module.network.network_id
  subnet_id  = module.network.runtime_subnet_id

  min_instances = 1
  max_instances = 20

  env = {
    LOG_LEVEL = "info"
    DB_HOST   = module.database.private_ip
  }

  secret_env = {
    DB_PASSWORD = { secret = "orders-api-db-password" }
    API_SIGNING_KEY = {
      secret  = "orders-api-signing-key"
      version = "3"
    }
  }

  enable_job  = true
  job_command = ["python", "-m", "alembic"]
  job_args    = ["upgrade", "head"]
}

# Least privilege happens at the caller, scoped to concrete resources:
resource "google_secret_manager_secret_iam_member" "db_password" {
  secret_id = "orders-api-db-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${module.orders_api.service_account_email}"
}
```

## Opinions

- **CI owns the image, Terraform owns everything else.** `lifecycle.ignore_changes` covers only the container image on both the service and the job. CI builds an immutable digest once and promotes that exact digest through environments; Terraform never participates in releases and can never roll a service back to a stale image by accident. The `image` variable is a bootstrap value for the first apply only, and `:latest` is rejected at plan time because it is not reproducible or auditable.
- **Internal ingress by default.** `ingress` defaults to `INGRESS_TRAFFIC_INTERNAL_LOAD_BALANCER`; reaching the public internet directly through the run.app URL requires a caller to opt in explicitly. Egress is direct VPC (`PRIVATE_RANGES_ONLY`, no serverless connector to operate or pay for), so outbound internet traffic only exists if the VPC routes it through NAT deliberately.
- **No service account keys, ever, and no project-level roles.** The module creates a dedicated per-workload identity and grants it nothing. Callers attach resource-scoped roles to the exported email (a specific secret, a specific bucket, a specific database). There is no `google_service_account_key` resource here and never will be — workload identity makes exported keys pure liability.
- **Secrets are references, not values.** Secret material enters the container only via Secret Manager `secret_key_ref`; the `env` map is for plaintext configuration only. Name collisions between `env` and `secret_env`, and attempts to set Cloud Run's reserved variables (`PORT`, `K_SERVICE`, ...), fail validation before a plan exists.
- **Migrations do not auto-retry.** The companion job defaults to `job_max_retries = 0`: a failed schema migration is a stop-the-line event that needs a human, not a blind re-run that can compound partial state.
- **Scaling bounds are mandatory and sane.** `max_instances` is the cost and blast-radius ceiling and is validated to be `>= min_instances` at plan time, not discovered at apply time.
