variable "name_prefix" {
  type        = string
  description = "Prefix for all resource names (e.g. \"platform-prod\"). Lowercase letters, digits, and hyphens; hyphens are converted to underscores for the BigQuery dataset id."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,28}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-30 characters, start with a lowercase letter, end with a letter or digit, and contain only lowercase letters, digits, and hyphens."
  }
}

variable "project_id" {
  type        = string
  description = "GCP project that hosts both the log sink and the destination BigQuery dataset."

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{4,28}[a-z0-9]$", var.project_id))
    error_message = "project_id must be a valid GCP project id (6-30 characters, lowercase letters, digits, hyphens, starting with a letter)."
  }
}

variable "location" {
  type        = string
  description = "BigQuery dataset location (multi-region such as \"US\"/\"EU\" or a single region such as \"europe-west1\"). If kms_key_name is set, the key ring location must be compatible with this value."

  validation {
    condition     = can(regex("^[A-Za-z][A-Za-z0-9-]+$", var.location))
    error_message = "location must be a BigQuery location identifier such as \"US\", \"EU\", or \"europe-west1\"."
  }
}

variable "retention_years" {
  type        = number
  description = "Years to retain audit log partitions before BigQuery drops them. 0 means retain indefinitely (no expiration). Pick the value your regulator or internal policy mandates, not a guess."
  default     = 7

  validation {
    condition     = var.retention_years >= 0 && var.retention_years <= 100 && floor(var.retention_years) == var.retention_years
    error_message = "retention_years must be a whole number between 0 (keep forever) and 100."
  }
}

variable "log_filter" {
  type        = string
  description = "Logging filter selecting which entries the sink exports. Defaults to structured audit logs written under a */logs/audit log name."
  default     = "logName=~\"projects/.+/logs/audit\""

  validation {
    condition     = length(trimspace(var.log_filter)) > 0
    error_message = "log_filter must not be empty: an empty filter would export every log entry in the project into the archive dataset."
  }
}

variable "kms_key_name" {
  type        = string
  description = "Optional Cloud KMS key (full resource name) used as the dataset's default CMEK. Null uses Google-managed encryption."
  default     = null
  nullable    = true

  validation {
    condition     = var.kms_key_name == null || can(regex("^projects/[^/]+/locations/[^/]+/keyRings/[^/]+/cryptoKeys/[^/]+$", var.kms_key_name))
    error_message = "kms_key_name must be a full key resource name: projects/PROJECT/locations/LOCATION/keyRings/RING/cryptoKeys/KEY."
  }
}
