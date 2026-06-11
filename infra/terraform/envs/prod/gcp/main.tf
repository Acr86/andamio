# Production on GCP.
#
# Deployment posture (mirrors the CI design):
#   - staging auto-applies on every merge to main;
#   - production applies the SAME plan behind a manual approval gate.
# Both environments deploy artifacts built from refs/heads/main: the image is
# identical, only the gate differs. The trust policy therefore allows the same
# ref in both environments; the human gate lives in the pipeline, not in IAM.
#
# Everything stateful is protected: regional (HA) database with PITR and
# deletion protection, seven-year audit retention, no scale-to-zero.

locals {
  name_prefix = "platform-prod"
}

module "network" {
  source = "../../../modules/gcp/network"

  name_prefix = local.name_prefix
  region      = var.region
  # Production owns 10.10.0.0/20; staging owns 10.20.0.0/20. Non-overlapping
  # by design so the environments could be peered for migrations if ever needed.
  subnet_cidr       = "10.10.0.0/20"
  flow_log_sampling = 0.5
}

module "registry" {
  source = "../../../modules/gcp/registry"

  project_id  = var.project_id
  name        = "${local.name_prefix}-images"
  location    = var.region
  description = "Application container images for the production environment. Pushed exclusively by the GitHub Actions deploy workflow after the manual release gate; pulled by Cloud Run."

  untagged_retention_days = 7
  keep_tagged_count       = 30
}

module "database" {
  source = "../../../modules/gcp/database"

  name          = "${local.name_prefix}-pg"
  region        = var.region
  network_id    = module.network.network_id
  database_name = "app"

  tier                  = "db-custom-2-7680"
  ha                    = true
  pitr                  = true
  backup_retention_days = 30
  deletion_protection   = true

  labels = {
    environment = "production"
    managed-by  = "terraform"
  }

  # network_id alone does not order this module against the Private Services
  # Access peering the network module creates; depend on the whole module so
  # the first apply does not race the service networking connection.
  depends_on = [module.network]
}

module "runtime" {
  source = "../../../modules/gcp/serverless-runtime"

  project_id = var.project_id
  region     = var.region
  name       = "${local.name_prefix}-app"

  image = "${module.registry.repository_url}/app:${var.app_image_tag}"

  network_id = module.network.network_id
  subnet_id  = module.network.subnet_id

  # One instance always warm: production never pays a cold start to serve
  # the first request after an idle period.
  min_instances = 1
  max_instances = 10
  cpu_limit     = "2"
  memory_limit  = "1Gi"

  env = {
    APP_ENV = "production"
    DB_HOST = module.database.private_ip_address
    DB_NAME = module.database.database_name
  }

  # Companion Cloud Run job for schema migrations: same image, identity, and
  # network as the service, executed by CI before traffic shifts.
  enable_job = true
}

module "cicd_identity" {
  source = "../../../modules/gcp/cicd-identity"

  project_id        = var.project_id
  name_prefix       = local.name_prefix
  github_repository = var.github_repository
  allowed_refs      = ["refs/heads/main"]
}

module "audit_log_sink" {
  source = "../../../modules/gcp/audit-log-sink"

  project_id  = var.project_id
  name_prefix = local.name_prefix
  location    = var.region
  # Seven years: the longest common regulatory retention window for financial
  # and operational audit records. Set deliberately, not as a guess.
  retention_years = 7
}
