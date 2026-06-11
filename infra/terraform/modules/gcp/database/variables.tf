variable "name" {
  type        = string
  description = "Cloud SQL instance name. Must be unique within the project; note that deleted instance names are reserved for roughly a week."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,95}[a-z0-9]$", var.name))
    error_message = "Instance name must start with a letter, contain only lowercase letters, digits, and hyphens, end alphanumerically, and be at most 97 characters."
  }
}

variable "region" {
  type        = string
  description = "GCP region for the instance (e.g. europe-west1). Pick the same region as the workloads that talk to it; cross-region SQL traffic is latency you pay for forever."

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "Region must be a valid GCP region identifier such as europe-west1 or us-central1."
  }
}

variable "network_id" {
  type        = string
  description = "Fully qualified VPC network id (projects/PROJECT/global/networks/NAME) used for private IP. The VPC must already have a service networking connection (private services access); the network module provisions it."

  validation {
    condition     = can(regex("^projects/[^/]+/global/networks/[a-z]([a-z0-9-]*[a-z0-9])?$", var.network_id))
    error_message = "network_id must be a fully qualified network id: projects/PROJECT/global/networks/NAME."
  }
}

variable "database_name" {
  type        = string
  description = "Name of the logical database created on the instance."

  validation {
    condition     = can(regex("^[a-zA-Z_][a-zA-Z0-9_]{0,62}$", var.database_name))
    error_message = "Database name must be a valid PostgreSQL identifier: start with a letter or underscore, contain only letters, digits, and underscores, max 63 characters."
  }
}

variable "tier" {
  type        = string
  description = "Cloud SQL machine tier. Defaults to a small dedicated-core shape (1 vCPU / 3.75 GB); shared-core tiers are not recommended for anything that serves traffic."
  default     = "db-custom-1-3840"

  validation {
    condition     = can(regex("^db-", var.tier))
    error_message = "Tier must be a Cloud SQL tier identifier starting with 'db-' (e.g. db-custom-2-7680)."
  }
}

variable "ha" {
  type        = bool
  description = "When true the instance runs REGIONAL (synchronous standby in a second zone, automatic failover). When false it runs ZONAL. Flip to true for production; keep false in pre-production to halve the bill."
  default     = false
}

variable "backup_retention_days" {
  type        = number
  description = "Number of automated daily backups to retain."
  default     = 7

  validation {
    condition     = var.backup_retention_days >= 1 && var.backup_retention_days <= 365
    error_message = "backup_retention_days must be between 1 and 365."
  }
}

variable "pitr" {
  type        = bool
  description = "Enable point-in-time recovery (continuous WAL archiving). Leave on unless this instance holds purely disposable data."
  default     = true
}

variable "deletion_protection" {
  type        = bool
  description = "Block 'terraform destroy' from deleting the instance. Disable deliberately, in a separate change, when a teardown is actually intended."
  default     = true
}

variable "maintenance_window_day" {
  type        = number
  description = "Day of week (1 = Monday ... 7 = Sunday) for the Cloud SQL maintenance window."
  default     = 7

  validation {
    condition     = var.maintenance_window_day >= 1 && var.maintenance_window_day <= 7
    error_message = "maintenance_window_day must be between 1 (Monday) and 7 (Sunday)."
  }
}

variable "maintenance_window_hour" {
  type        = number
  description = "Hour of day (0-23, UTC) for the Cloud SQL maintenance window. Default 03:00 UTC, i.e. off-peak for European and American traffic."
  default     = 3

  validation {
    condition     = var.maintenance_window_hour >= 0 && var.maintenance_window_hour <= 23
    error_message = "maintenance_window_hour must be between 0 and 23."
  }
}

variable "labels" {
  type        = map(string)
  description = "Labels applied to the instance for cost attribution and inventory."
  default     = {}
}
