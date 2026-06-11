# Staging on AWS: the disposable twin of production.
# Same module set, same wiring, different dials: single-AZ database without
# deletion protection, minimal App Runner footprint, short retentions.
# Anything here must survive a full destroy/recreate without ceremony.

locals {
  name_prefix = "platform-staging"
  # Staging owns 10.20.0.0/16; production owns 10.10.0.0/16. Non-overlapping
  # by design so the environments could be peered for migrations if ever needed.
  vpc_cidr = "10.20.0.0/16"
}

module "network" {
  source = "../../../modules/aws/network"

  name_prefix = local.name_prefix
  vpc_cidr    = local.vpc_cidr
  az_count    = 2
  # Network telemetry is security evidence even in staging: a year, encrypted
  # with the audit CMK (its policy already trusts CloudWatch Logs).
  flow_log_retention_days = 365
  flow_log_kms_key_arn    = module.audit_log_sink.kms_key_arn
}

module "registry" {
  source = "../../../modules/aws/registry"

  name                    = "${local.name_prefix}/app"
  untagged_retention_days = 3
  keep_tagged_count       = 10
  # Staging is disposable: destroy must not strand on leftover images.
  force_delete = true
}

module "database" {
  source = "../../../modules/aws/database"

  name               = "${local.name_prefix}-pg"
  vpc_id             = module.network.vpc_id
  private_subnet_ids = module.network.private_subnet_ids
  database_name      = "app"

  # Ingress is scoped to the runtime's VPC-connector security group: the
  # workload's identity, not a network range. (No cycle: the SG resource and
  # the DB instance have no resource-level dependency on each other.)
  allowed_security_group_ids = [module.runtime.connector_security_group_id]

  instance_class          = "db.t4g.micro"
  allocated_storage       = 20
  max_allocated_storage   = 100
  ha                      = false
  backup_retention_period = 1
  deletion_protection     = false
}

module "runtime" {
  source = "../../../modules/aws/serverless-runtime"

  name  = "${local.name_prefix}-app"
  image = "${module.registry.repository_url}:${var.app_image_tag}"

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
  public     = false

  # App Runner has no scale-to-zero; one instance is the smallest idle bill.
  min_instances = 1
  max_instances = 2
  cpu           = "1024"
  memory        = "2048"

  env = {
    APP_ENV = "staging"
    DB_HOST = module.database.address
    DB_NAME = module.database.database_name
  }

  secret_env = {
    DATABASE_CREDENTIALS = module.database.master_user_secret_arn
  }
}

module "cicd_identity" {
  source = "../../../modules/aws/cicd-identity"

  name_prefix       = local.name_prefix
  github_repository = var.github_repository
  allowed_refs      = ["refs/heads/main"]
}

module "audit_log_sink" {
  source = "../../../modules/aws/audit-log-sink"

  name_prefix        = local.name_prefix
  log_group_name     = "/platform/staging/audit"
  log_retention_days = 365
  # Module minimum: staging audit data carries no regulatory hold.
  retention_years = 1
  # GOVERNANCE is bypassable with a privileged action on purpose:
  # staging teardown must remain possible.
  worm_mode = "GOVERNANCE"
}
