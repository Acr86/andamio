# Production on AWS.
#
# Deployment posture (mirrors the CI design):
#   - staging auto-applies on every merge to main;
#   - production applies the SAME plan behind a manual approval gate.
# Both environments deploy artifacts built from refs/heads/main: the image is
# identical, only the gate differs. The trust policy therefore allows the same
# ref in both environments; the human gate lives in the pipeline, not in IAM.
#
# Everything stateful is protected: Multi-AZ database with deletion protection,
# COMPLIANCE-mode WORM audit archive, seven-year retention, three AZs.

locals {
  name_prefix = "platform-prod"
  # Production owns 10.10.0.0/16; staging owns 10.20.0.0/16. Non-overlapping
  # by design so the environments could be peered for migrations if ever needed.
  vpc_cidr = "10.10.0.0/16"
}

module "network" {
  source = "../../../modules/aws/network"

  name_prefix             = local.name_prefix
  vpc_cidr                = local.vpc_cidr
  az_count                = 3
  flow_log_retention_days = 365
  flow_log_kms_key_arn    = module.audit_log_sink.kms_key_arn
}

module "registry" {
  source = "../../../modules/aws/registry"

  name                    = "${local.name_prefix}/app"
  untagged_retention_days = 7
  keep_tagged_count       = 30
  # A destroy that would take deployed image history with it must fail loudly.
  force_delete = false
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

  instance_class          = "db.m6g.large"
  allocated_storage       = 100
  max_allocated_storage   = 500
  ha                      = true
  backup_retention_period = 30
  deletion_protection     = true
}

module "runtime" {
  source = "../../../modules/aws/serverless-runtime"

  name  = "${local.name_prefix}-app"
  image = "${module.registry.repository_url}:${var.app_image_tag}"

  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnet_ids
  public     = false

  # Two instances minimum: a single-instance production service turns every
  # deployment and instance recycle into a partial outage.
  min_instances = 2
  max_instances = 10
  cpu           = "2048"
  memory        = "4096"

  env = {
    APP_ENV = "production"
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
  log_group_name     = "/platform/prod/audit"
  log_retention_days = 365
  # Seven years: the longest common regulatory retention window for financial
  # and operational audit records. Set deliberately, not as a guess.
  retention_years = 7
  # COMPLIANCE mode: nobody, including the root user, can shorten retention.
  worm_mode = "COMPLIANCE"
}
