# Staging on GCP: the disposable twin of production.
# Same module set, same wiring, different dials: zonal database without
# deletion protection, scale-to-zero runtime, short retentions. Anything
# here must survive a full destroy/recreate without ceremony.

locals {
  name_prefix = "platform-staging"
}

module "network" {
  source = "../../../modules/gcp/network"

  name_prefix = local.name_prefix
  region      = var.region
  # Staging owns 10.20.0.0/20; production owns 10.10.0.0/20. Non-overlapping
  # by design so the environments could be peered for migrations if ever needed.
  subnet_cidr       = "10.20.0.0/20"
  flow_log_sampling = 0.1
}

module "registry" {
  source = "../../../modules/gcp/registry"

  project_id  = var.project_id
  name        = "${local.name_prefix}-images"
  location    = var.region
  description = "Application container images for the staging environment. Pushed exclusively by the GitHub Actions deploy workflow; pulled by Cloud Run."

  untagged_retention_days = 3
  keep_tagged_count       = 10
}

module "database" {
  source = "../../../modules/gcp/database"

  name          = "${local.name_prefix}-pg"
  region        = var.region
  network_id    = module.network.network_id
  database_name = "app"

  tier                  = "db-custom-1-3840"
  ha                    = false
  pitr                  = false
  backup_retention_days = 3
  deletion_protection   = false

  labels = {
    environment = "staging"
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

  min_instances = 0
  max_instances = 3

  env = {
    APP_ENV = "staging"
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
  # Staging audit data carries no regulatory hold; one year covers debugging.
  retention_years = 1
}
